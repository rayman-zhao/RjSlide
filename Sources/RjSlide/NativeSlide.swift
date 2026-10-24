import Foundation
import JavaUtilFunction
import LibJPEGTurbo
import RsFoundation
import RsSlide
import SwiftJava

/// RsSlide is a protocol, need a wrapper for Unmanaged pointer convension.
final class SlideWrapper {
    let lock = NSLock()
    let slide: RsSlide.Slide
    var macroRotation: Int?

    init(_ slide: RsSlide.Slide) {
        self.slide = slide
    }

    static func from(bits: Int64) -> Unmanaged<SlideWrapper> {
        let ptr = UnsafeRawPointer(bitPattern: Int(bits))!
        return Unmanaged<SlideWrapper>.fromOpaque(ptr)
    }

    static func from(bits: Int64) -> SlideWrapper {
        let ptr = UnsafeRawPointer(bitPattern: Int(bits))!
        return Unmanaged<SlideWrapper>.fromOpaque(ptr).takeUnretainedValue()
    }
}

private func javaBytes(_ data: [UInt8]) -> [Int8] {
    data.withUnsafeBytes { Array($0.bindMemory(to: Int8.self)) }
}

@JavaImplementation("dev.swiftworks.ruslan.Slide")
extension Slide: SlideNativeMethods {
    @JavaMethod
    func create(_ path: String) -> Int64 {
        guard case .slide(let builder) = URL(filePath: path).slideKind,
            let slide = builder.makeSlide()
        else { return 0 }

        let ptr = Unmanaged.passRetained(SlideWrapper(slide)).toOpaque()
        return Int64(Int(bitPattern: ptr))
    }

    @JavaMethod
    static func release(_ nativeSlide: Int64, environment: JNIEnvironment? = nil) {
        guard nativeSlide != 0 else { return }

        let wrapper: Unmanaged<SlideWrapper> = SlideWrapper.from(bits: nativeSlide)
        wrapper.release()
    }

    @JavaMethod
    func getMacro() -> [Int8] {
        withSlide { fetchMacroLocked($0) } ?? []
    }

    @JavaMethod
    func getLabel() -> [Int8] {
        withSlide { wrapper in
            guard let img: [UInt8] = wrapper.slide.fetchLabelJPEGImage() else { return [] }
            let rotatedImg = tjRotate(img, degrees: forceMacroRotation(wrapper)) ?? img
            return javaBytes(rotatedImg)
        } ?? []
    }

    @JavaMethod
    func getTile(_ imageId: String, _ tier: Int32, _ layer: Int32, _ x: Int32, _ y: Int32) -> [Int8]
    {
        withSlide { wrapper in
            let coord = TileCoordinate(layer: Int(layer), row: Int(y), col: Int(x), tier: Int(tier))
            guard let img: [UInt8] = wrapper.slide.fetchTileImage(for: coord) else { return [] }
            return javaBytes(img)
        } ?? []
    }

    @JavaMethod
    func getThumbnail(_ maxSize: Int32) -> [Int8] {
        withSlide { wrapper in
            guard let img: [UInt8] = wrapper.slide.fetchThumbnailJPEGImage(maxSize: Int(maxSize))
            else { return [] }
            return javaBytes(img)
        } ?? []
    }

    @JavaMethod
    func getUploadSlideDTO() -> String {
        withSlide { uploadSlideDTO($0) } ?? ""
    }

    private func withSlide<T>(_ body: (SlideWrapper) throws -> T) rethrows -> T? {
        guard self.nativeSlide != 0 else { return nil }

        let wrapper: SlideWrapper = SlideWrapper.from(bits: self.nativeSlide)
        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }
        return try body(wrapper)
    }

    /// The wrapper's lock must be held by the caller.
    private func fetchMacroLocked(_ wrapper: SlideWrapper) -> [Int8] {
        guard let img: [UInt8] = wrapper.slide.fetchMacroJPEGImage() else {
            wrapper.macroRotation = 0
            return []
        }

        let (width, height) = tjDecompressHeader(img)
        guard width > 0, height > 0, width < height, let rotatedImg = tjRotate(img, degrees: -90)
        else {
            wrapper.macroRotation = 0
            return javaBytes(img)
        }

        wrapper.macroRotation = -90
        return javaBytes(rotatedImg)
    }

    /// The wrapper's lock must be held by the caller.
    private func uploadSlideDTO(_ wrapper: SlideWrapper) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let slide = wrapper.slide
        let imgDTO = ImageDTO(
            width: slide.layerImageSize[0].w,
            height: slide.layerImageSize[0].h,
            scanObjective: slide.scanObjective,
            calibration: slide.scanScale,
            tileWidth: slide.tileTrait.size.w,
            tileHeight: slide.tileTrait.size.h,
            backgroundColor: slide.tileTrait.backgroundColorRGB,
            layerZoom: slide.layerZoom,
            layers: slide.layerTileSize.enumerated().map { (index, size) in
                LayerDTO(
                    index: index,
                    rows: size.r,
                    cols: size.c,
                    scale: 1.0 / pow(2, Double(index))
                )
            }
        )

        let rotation = forceMacroRotation(wrapper)
        let rotationXML = rotation != 0 ? "<item rotation=\"\(rotation)\" />" : ""
        let extXML =
            slide.extendedXML.isEmpty && rotationXML.isEmpty
            ? "" : "<Motic>\(rotationXML)\(slide.extendedXML)</Motic>"

        let slideDTO = UploadSlideDTO(
            id: slide.id.uuidString,
            name: slide.name,
            barcode: "",
            tierCount: slide.tierTrait.count,
            tierSpacing: slide.tierTrait.spacing,
            createTime: slide.createTime,
            size: slide.dataSize,
            manufacturer: slide.format,
            extend: "<ROOT><SlidePath>\(slide.mainPath.xmlEscaped())</SlidePath>\(extXML)</ROOT>",
            images: [imgDTO]
        )

        guard let data = try? encoder.encode(slideDTO),
            let json = String(data: data, encoding: .utf8)
        else { return "" }
        return json
    }

    /// The wrapper's lock must be held by the caller.
    private func forceMacroRotation(_ wrapper: SlideWrapper) -> Int {
        if wrapper.macroRotation == nil {
            _ = fetchMacroLocked(wrapper)
        }
        return wrapper.macroRotation ?? 0
    }
}
