import CRegister
import Foundation
import JavaUtilFunction
import SwiftJava

@JavaImplementation("dev.swiftworks.ruslan.Register")
extension Register: RegisterNativeMethods {
    @JavaMethod
    func runPixelsRGB24(
        _ rgb: [Int8], _ w: Int32, _ h: Int32, _ rgb2: [Int8], _ w2: Int32, _ h2: Int32
    ) -> String {
        return rgb.withUnsafeBytes { fixed in
            return rgb2.withUnsafeBytes { moving in
                var buf = [CChar](repeating: 0, count: 4096)
                let res = rigid_register_run_pixels_rgb24(
                    fixed.bindMemory(to: UInt8.self).baseAddress!, w, h,
                    moving.bindMemory(to: UInt8.self).baseAddress!, w2, h2,
                    10, &buf, buf.count, nil)
                if res == 0 {
                    return String(cString: buf)
                } else {
                    return """
                        {
                            "result": {
                                "reg_ok": 0,
                                "err": "Buffer too small"
                            }
                        }
                        """
                }
            }
        }
    }

    @JavaMethod
    func runPaths(_ fn: String, _ fn2: String, _ output: String) -> String {
        return output.withCString { out in
            return fn2.withCString { moving in
                return fn.withCString { fixed in
                    var buf = [CChar](repeating: 0, count: 4096)
                    let res = rigid_register_run_paths(fixed, moving, 10, &buf, buf.count, out)
                    if res == 0 {
                        return String(cString: buf)
                    } else {
                        return """
                            {
                                "result": {
                                    "reg_ok": 0,
                                    "err": "Buffer too small"
                                }
                            }
                            """
                    }
                }
            }
        }
    }
}
