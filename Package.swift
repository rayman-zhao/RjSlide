// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

import class Foundation.FileManager
import class Foundation.ProcessInfo

// Note: the JAVA_HOME environment variable must be set to point to where
// Java is installed, e.g.,
//   Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home.
func findJavaHome() -> String {
  if let home = ProcessInfo.processInfo.environment["JAVA_HOME"] {
    return home
  }

  // This is a workaround for envs (some IDEs) which have trouble with
  // picking up env variables during the build process
  let path = "\(FileManager.default.homeDirectoryForCurrentUser.path()).java_home"
  if let home = try? String(contentsOfFile: path, encoding: .utf8) {
    if let lastChar = home.last, lastChar.isNewline {
      return String(home.dropLast())
    }

    return home
  }

  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}
let javaHome = findJavaHome()

let javaIncludePath = "\(javaHome)/include"
#if os(Linux)
  let javaPlatformIncludePath = "\(javaIncludePath)/linux"
#elseif os(macOS)
  let javaPlatformIncludePath = "\(javaIncludePath)/darwin"
#elseif os(Windows)
  let javaPlatformIncludePath = "\(javaIncludePath)/win32)"
#endif

let OpenCVLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-L\(Context.packageDirectory)/opencv_x64-windows"], .when(platforms: [.windows])),
    .linkedLibrary("ittnotify"),
    .linkedLibrary("opencv_calib3d4120"),
    .linkedLibrary("opencv_core4120"),
    .linkedLibrary("opencv_features2d4120"),
    .linkedLibrary("opencv_flann4120"),
    .linkedLibrary("opencv_imgcodecs4120"),
    .linkedLibrary("opencv_imgproc4120"),
    //.linkedLibrary("libjpeg-turbo"), // Not same as the official release, so have to remove it for now.
    // .linkedLibrary("libpng"), // Use RsPack version
    // .linkedLibrary("zlib"), // Use RsPack version
]

let package = Package(
  name: "RjSlide",
  platforms: [
    .macOS(.v15),
  ],

  products: [
    .library(
      name: "RjSlide",
      type: .dynamic,
      targets: ["RjSlide"]
    ),
  ],

  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-java.git", branch: "main"),
    .package(url: "https://github.com/rayman-zhao/RsSlide.git", branch: "main"),
  ],

  targets: [
    .target(
      name: "RjSlide",
      dependencies: [
        .product(name: "JavaUtilFunction", package: "swift-java"),
        .product(name: "RsSlide", package: "RsSlide"),
        .target(name: "CRegister_x64-windows", condition: .when(platforms: [.windows])),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ],
      linkerSettings: [
          .unsafeFlags(["-L\(Context.packageDirectory)/Sources/CRegister_x64-windows/Lib"], .when(platforms: [.windows])),
      ] + OpenCVLinkerSettings,
      plugins: [
        .plugin(name: "JavaCompilerPlugin", package: "swift-java"),
        .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
      ]
    ),
    .systemLibrary(
      name: "CRegister_x64-windows",
    ),
  ]
)
