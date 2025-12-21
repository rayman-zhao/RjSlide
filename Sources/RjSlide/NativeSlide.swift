import Foundation
import SwiftJava
import JavaUtilFunction
import RsSlide

// RsSlide is a protocol, need a wrapper for Unmanaged pointer convension.
final class SlideWrapper {
    let lock = NSLock()
    let slide: RsSlide.Slide

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

@JavaImplementation("dev.swiftworks.ruslan.Slide")
extension Slide: SlideNativeMethods {
    @JavaMethod
    func create(_ path: String) -> Int64 {
        let trait = URL(filePath: path).slideTrait
        guard case .isSlide(let builder) = trait, let slide = builder.makeView() else { return 0 }

        let ptr = Unmanaged.passRetained(SlideWrapper(slide)).toOpaque()
        return Int64(Int(bitPattern: ptr))
    }

    @JavaMethod
    func release() {
        let wrapper:Unmanaged<SlideWrapper> = SlideWrapper.from(bits: self.nativeSlide)
        wrapper.release()
    }

    @JavaMethod
    func getMacro() -> [Int8] {
        let wrapper: SlideWrapper = SlideWrapper.from(bits: self.nativeSlide)
        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }

        let img: [UInt8] = wrapper.slide.fetchMacroJPEGImage()
        return img.withUnsafeBytes { buf in
            Array(buf.bindMemory(to: Int8.self))
        }
    }

    @JavaMethod
    func getLabel() -> [Int8] {
        let wrapper: SlideWrapper = SlideWrapper.from(bits: self.nativeSlide)
        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }

        let img: [UInt8] = wrapper.slide.fetchLabelJPEGImage()
        return img.withUnsafeBytes { buf in
            Array(buf.bindMemory(to: Int8.self))
        }
    }

    @JavaMethod
    func getTile(_ imageId: String, _ tier: Int32, _ layer: Int32, _ x: Int32, _ y: Int32) -> [Int8] {
        let wrapper: SlideWrapper = SlideWrapper.from(bits: self.nativeSlide)
        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }

        let coord = TileCoordinate(layer: Int(layer), row: Int(y), col: Int(x), tier: Int(tier))
        let img: [UInt8] = wrapper.slide.fetchTileRawImage(at: coord)
        return img.withUnsafeBytes { buf in
            Array(buf.bindMemory(to: Int8.self))
        }
    }

    @JavaMethod
    func getThumbnail(_ maxSize: Int32) -> [Int8] {
        let wrapper: SlideWrapper = SlideWrapper.from(bits: self.nativeSlide)
        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }

        let img: [UInt8] = wrapper.slide.fetchThumbnailJPEGImage(with: Int(maxSize))
        return img.withUnsafeBytes { buf in
            Array(buf.bindMemory(to: Int8.self))
        }
    }

    @JavaMethod
    func getUploadSlideDTO() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let slide = SlideWrapper.from(bits: self.nativeSlide).slide
        let imgDTO = ImageDTO(
            width: slide.layerImageSize[0].w,
            height: slide.layerImageSize[0].h,
            scanObjective: Double(slide.scanObjective),
            calibration: slide.scanScale,
            tileWidth: slide.tileTrait.size.w,
            tileHeight: slide.tileTrait.size.h,
            backgroundColor: slide.tileTrait.rgbBackground,
            layers: slide.layerTileSize.enumerated().map { (index, size) in 
                LayerDTO(
                    index: index,
                    rows: size.r,
                    cols: size.c,
                    scale: 1.0 / pow(2, Double(index))
                )
            }
        )
        let slideDTO = UploadSlideDTO(
            id: slide.id.uuidString,
            name: slide.name,
            barcode: "",
            tierCount: slide.tierCount,
            tierSpacing: slide.tierSpacing,
            createTime: slide.createTime,
            size: slide.dataSize,
            manufacturer: slide.format,
            extend: "<ROOT><SlidePath>\(slide.mainPath)</SlidePath>\(slide.extendXMLString)</ROOT>",
            images: [imgDTO]
        )

        if let data = try? encoder.encode(slideDTO),
            let json = String(data: data, encoding: .utf8) {
                return json
        } else {
            return ""
        }
    }
}