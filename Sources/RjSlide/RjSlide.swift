import Foundation
import SwiftJava
import JavaUtilFunction
import RsSlide

fileprivate let lock = NSLock()
fileprivate var openedSlides: [String : RsSlide.Slide] = [:]

@JavaImplementation("dev.swiftworks.ruslan.Slide")
extension Slide: SlideNativeMethods {
    @JavaMethod
    func create(_ path: String) -> Bool {
        let trait = URL(filePath: path).slideTrait
        guard case .isSlide(let builder) = trait, let slide = builder.makeView() else { return false }

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

        lock.lock()
        defer { lock.unlock() }
        
        openedSlides[path] = slide
        return true
    }

    @JavaMethod
    func release(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        _ = openedSlides.removeValue(forKey: path)

    #if DEBUG
        print("Removed \(path)")
        print("Left \(openedSlides.count)")
    #endif
    }

    @JavaMethod
    func macro(_ path: String) -> [Int8] {
        lock.lock()
        defer { lock.unlock() }
        
        if let slide = openedSlides[path] {
            let img: [UInt8] = slide.fetchMacroJPEGImage()
            return img.withUnsafeBytes { buf in
                Array(buf.bindMemory(to: Int8.self))
            }
        }
        
        return []
    }

    @JavaMethod
    func label(_ path: String) -> [Int8] {
        lock.lock()
        defer { lock.unlock() }
        
        if let slide = openedSlides[path] {
            let img: [UInt8] = slide.fetchLabelJPEGImage()
            return img.withUnsafeBytes { buf in
                Array(buf.bindMemory(to: Int8.self))
            }
        }
        
        return []
    }

    @JavaMethod
    func tile(_ path: String, _ tier: Int32, _ layer: Int32, _ x: Int32, _ y: Int32) -> [Int8] {
        lock.lock()
        defer { lock.unlock() }
        
        if let slide = openedSlides[path] {
            let coord = TileCoordinate(layer: Int(layer), row: Int(y), col: Int(x), tier: Int(tier))
            let img: [UInt8] = slide.fetchTileRawImage(at: coord)
            return img.withUnsafeBytes { buf in
                Array(buf.bindMemory(to: Int8.self))
            }
        }
        
        return []
    }
}