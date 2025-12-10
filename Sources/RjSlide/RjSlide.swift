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
        print("Removed \(path)")

        lock.lock()
        defer { lock.unlock() }
        _ = openedSlides.removeValue(forKey: path)

        print("Left \(openedSlides.count)")
    }
}