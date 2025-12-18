import Foundation

struct LayerDTO: Encodable {
    let index: Int
    let rows: Int
    let cols: Int
    let scale: Double
}

struct ImageDTO: Encodable {
    let id = "f"
    let width: Int
    let height: Int
    let scanObjective: Double
    let calibration:Double
    let tileWidth: Int
    let tileHeight: Int
    let backgroundColor: Int
    let layers: [LayerDTO]
}

struct UploadSlideDTO: Encodable {
    let id: String
    let name: String
    let barcode: String
    let tierCount: Int
    let tierSpacing: Double
    //let storage = 0
    //let storageStatus = 1
    //let status = 0
    //let groupSize = 0;
    let createTime: Date
    //finishTime=new Date();
    let size: Int
    let manufacturer: String
    let extend: String
    //rois= List.of();
    let images: [ImageDTO]
}