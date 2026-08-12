import Foundation
import AppKit

let dest = CommandLine.arguments[1]
func cargarCG(_ n:String) -> CGImage {
    let d = try! Data(contentsOf: URL(fileURLWithPath:"\(dest)/\(n)"))
    return NSBitmapImageRep(data: d)!.cgImage!
}
// Componer con CGContext directo: respeta el alfa de origen (NSBitmapImageRep.draw no).
func componer(src:CGImage, W:Int, H:Int, frac:CGFloat, fondo:CGColor?) -> CGContext {
    let ctx = CGContext(data:nil,width:W,height:H,bitsPerComponent:8,bytesPerRow:0,
        space:CGColorSpace(name:CGColorSpace.sRGB)!,
        bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    if let f = fondo { ctx.setFillColor(f); ctx.fill(CGRect(x:0,y:0,width:W,height:H)) }
    let sw = CGFloat(src.width), sh = CGFloat(src.height)
    let esc = min(CGFloat(W)*frac/sw, CGFloat(H)*frac/sh)
    let dw = sw*esc, dh = sh*esc
    ctx.draw(src, in: CGRect(x:(CGFloat(W)-dw)/2, y:(CGFloat(H)-dh)/2, width:dw, height:dh))
    return ctx
}
func guardar(_ ctx:CGContext,_ nombre:String,_ jpeg:Bool){
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    rep.size = NSSize(width: ctx.width, height: ctx.height)
    let d = jpeg ? rep.representation(using:.jpeg,properties:[.compressionFactor:0.9])!
                 : rep.representation(using:.png,properties:[:])!
    try! d.write(to:URL(fileURLWithPath:"\(dest)/\(nombre)"))
    print(String(format:"  %-20s %4dx%-4d %4d KB",(nombre as NSString).utf8String!,ctx.width,ctx.height,d.count/1024))
}

let mono = cargarCG("logo-mark-acento.png")
let full = cargarCG("cmm-wordmark.png")
let bg = NSColor(srgbRed:0xf8/255.0,green:0xf7/255.0,blue:0xf4/255.0,alpha:1).cgColor

guardar(componer(src:mono,W:512,H:512,frac:0.82,fondo:nil), "favicon.png", false)
guardar(componer(src:full,W:1200,H:630,frac:0.72,fondo:bg), "og.jpg", true)
