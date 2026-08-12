import Foundation
import PDFKit
import AppKit

let pdf = CommandLine.arguments[1]
let dest = CommandLine.arguments[2]
guard let doc = PDFDocument(url: URL(fileURLWithPath: pdf)), let page = doc.page(at: 2) else { exit(1) }

// --- Regiones medidas sobre el arte (coords PNG top-down del lienzo 1080) ---
// Bloque completo:      x 182..891   y 437..682
// Monograma:            x 182..410   y 437..627  (627 excluye el filete de y=630)
// Letras C.M.M.:        x 400..891   y 437..572
func pdfRect(_ x:CGFloat,_ yTop:CGFloat,_ w:CGFloat,_ yBot:CGFloat) -> CGRect {
    CGRect(x:x, y:1080-yBot, width:w, height:yBot-yTop)
}

func render(_ regiones:[CGRect], lienzo:CGRect, escala:CGFloat, fondo:NSColor?) -> NSBitmapImageRep? {
    let pw = Int((lienzo.width*escala).rounded()), ph = Int((lienzo.height*escala).rounded())
    guard let ctx = CGContext(data:nil,width:pw,height:ph,bitsPerComponent:8,bytesPerRow:0,
        space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.interpolationQuality = .high
    if let f = fondo { ctx.setFillColor(f.cgColor); ctx.fill(CGRect(x:0,y:0,width:pw,height:ph)) }
    ctx.scaleBy(x:escala,y:escala)
    ctx.translateBy(x:-lienzo.origin.x, y:-lienzo.origin.y)
    for r in regiones { ctx.saveGState(); ctx.clip(to:r); page.draw(with:.mediaBox,to:ctx); ctx.restoreGState() }
    guard let img = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: img); rep.size = NSSize(width:pw,height:ph); return rep
}

// Recorta los margenes transparentes sobrantes
func recortar(_ rep: NSBitmapImageRep) -> NSBitmapImageRep {
    let w = rep.pixelsWide, h = rep.pixelsHigh
    var minX=w, maxX = -1, minY=h, maxY = -1
    for y in 0..<h { for x in 0..<w {
        if let c = rep.colorAt(x:x,y:y), c.alphaComponent > 0.02 {
            if x<minX {minX=x}; if x>maxX {maxX=x}; if y<minY {minY=y}; if y>maxY {maxY=y} } } }
    if maxX < 0 { return rep }
    let cw = maxX-minX+1, chh = maxY-minY+1
    guard let cg = rep.cgImage?.cropping(to: CGRect(x:minX,y:minY,width:cw,height:chh)) else { return rep }
    let out = NSBitmapImageRep(cgImage: cg); out.size = NSSize(width:cw,height:chh); return out
}

func guardarPNG(_ rep: NSBitmapImageRep, _ nombre: String) {
    let d = rep.representation(using:.png, properties:[:])!
    try? d.write(to: URL(fileURLWithPath:"\(dest)/\(nombre)"))
    print(String(format:"  %-24s %4dx%-4d %5d KB  ratio %.2f", (nombre as NSString).utf8String!,
        rep.pixelsWide, rep.pixelsHigh, d.count/1024, Double(rep.pixelsWide)/Double(rep.pixelsHigh)))
}
func guardarJPG(_ rep: NSBitmapImageRep, _ nombre: String) {
    let d = rep.representation(using:.jpeg, properties:[.compressionFactor:0.88])!
    try? d.write(to: URL(fileURLWithPath:"\(dest)/\(nombre)"))
    print(String(format:"  %-24s %4dx%-4d %5d KB", (nombre as NSString).utf8String!, rep.pixelsWide, rep.pixelsHigh, d.count/1024))
}

let completo  = pdfRect(182,437,710,682)
let monograma = pdfRect(182,437,228,627)
let letras    = pdfRect(400,437,491,572)

print("Generando en \(dest):")

// 1) Wordmark completo para el hero  (ancho ~1600 => escala 1600/710)
if let r = render([completo], lienzo: completo, escala: 1600/710, fondo: nil) { guardarPNG(recortar(r), "cmm-wordmark.png") }

// 2) Compacto (monograma + C.M.M.) para header y footer
let lienzoCompacto = pdfRect(182,437,710,627)
if let r = render([monograma, letras], lienzo: lienzoCompacto, escala: 900/710, fondo: nil) { guardarPNG(recortar(r), "logo-cmm.png") }

// 3) Isotipo suelto
if let r = render([monograma], lienzo: monograma, escala: 4, fondo: nil) { guardarPNG(recortar(r), "logo-mark-acento.png") }
