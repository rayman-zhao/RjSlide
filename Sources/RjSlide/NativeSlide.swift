import Foundation
import SwiftJava
import JavaUtilFunction
import RsSlide

// RsSlide is a protocol, need a wrapper for Unmanaged pointer convension.
final class SlideWrapper {
    let slide: RsSlide.Slide

    init(_ slide: RsSlide.Slide) {
        self.slide = slide
    }
}

@JavaImplementation("dev.swiftworks.ruslan.Slide")
extension Slide: SlideNativeMethods {
    @JavaMethod
    func create(_ path: String) -> Int64 {
        let trait = URL(filePath: path).slideTrait
        guard case .isSlide(let builder) = trait, let slide = builder.makeView() else { return 0 }

    #if DEBUG
        print("SlideGUID: \(slide.id)")
        print("File size \(slide.dataSize)")
        print("Scan objective \(slide.scanObjective)")
        print("Scan scale \(slide.scanScale)")
    
        print("Tile size \(slide.tileTrait.size.w) x \(slide.tileTrait.size.h)")
        print("Tile format \(slide.tileTrait)")
        print("Layer zoom \(slide.layerZoom)")

        for i in 0..<slide.layerImageSize.count {
            print("Layer \(i) \(slide.layerImageSize[i].w)-\(slide.layerImageSize[i].h) in \(slide.layerTileSize[i].r)-\(slide.layerTileSize[i].c)")
        }
    #endif

        let ptr = Unmanaged.passRetained(SlideWrapper(slide)).toOpaque()
        return Int64(Int(bitPattern: ptr))
    }

    @JavaMethod
    func release() {
        if let ptr = UnsafeRawPointer(bitPattern: Int(self.nativeSlide)) {
            Unmanaged<SlideWrapper>.fromOpaque(ptr).release()
        }
    }

    @JavaMethod
    func getMacro() -> [Int8] {
        if let ptr = UnsafeRawPointer(bitPattern: Int(self.nativeSlide)) {
            let obj = Unmanaged<SlideWrapper>.fromOpaque(ptr).takeUnretainedValue()
            let img: [UInt8] = obj.slide.fetchMacroJPEGImage()
            return img.withUnsafeBytes { buf in
                Array(buf.bindMemory(to: Int8.self))
            }
        }
        
        return []
    }

    @JavaMethod
    func getLabel() -> [Int8] {
        if let ptr = UnsafeRawPointer(bitPattern: Int(self.nativeSlide)) {
            let obj = Unmanaged<SlideWrapper>.fromOpaque(ptr).takeUnretainedValue()
            let img: [UInt8] = obj.slide.fetchLabelJPEGImage()
            return img.withUnsafeBytes { buf in
                Array(buf.bindMemory(to: Int8.self))
            }
        }
        
        return []
    }

    @JavaMethod
    func getTile(_ imageId: String, _ tier: Int32, _ layer: Int32, _ x: Int32, _ y: Int32) -> [Int8] {
        if let ptr = UnsafeRawPointer(bitPattern: Int(self.nativeSlide)) {
            let obj = Unmanaged<SlideWrapper>.fromOpaque(ptr).takeUnretainedValue()
            let coord = TileCoordinate(layer: Int(layer), row: Int(y), col: Int(x), tier: Int(tier))
            let img: [UInt8] = obj.slide.fetchTileRawImage(at: coord)
            return img.withUnsafeBytes { buf in
                Array(buf.bindMemory(to: Int8.self))
            }
        }
        
        return []
    }
}