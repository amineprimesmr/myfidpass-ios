//
//  FlyerLogoBackgroundPrepared.swift
//  myfidpass
//
//  Détourage fond logo pour collage sur fond IA.
//  Stratégie : détection dynamique de la couleur de fond + BFS depuis tous les bords,
//  puis seconde passe sur les « cavités » (même couleur que le fond mais non reliée au bord :
//  trous fermés des lettres A, R, O, B, etc.).
//  Conditions requises pour appliquer le détourage :
//    1. L'image ne possède pas déjà de transparence significative (> 5 % des pixels).
//    2. Le fond détecté est uniforme : >= 50 % des pixels de bord appartiennent à la couleur
//       dominante estimée par histogramme sur l'ensemble des pixels de bord (robuste aux logos
//       avec éléments colorés aux coins). Évite de toucher aux photos ou fonds complexes.
//  Repli iOS 17+ : VNGenerateForegroundInstanceMaskRequest (fonds non uniformes) avec
//  critères de rejet si le masque est incohérent.
//  Ne pas sauter le détourage sur > 5 % de semi-transparence (bruit) : `isAlreadyRealTransparentCutout`
//  exige de vrais trous ; sinon on peut aplatir sur blanc (HEIC) puis BFS.
//

import CoreImage
import UIKit
import Vision

enum FlyerLogoBackgroundPrepared {

    /// Prépare le logo pour export flyer (PNG transparent).
    ///  1. Redimensionne à 1536 px max si nécessaire.
    ///  2. Si déjà transparent → retourné tel quel.
    ///  3. Si fond uniforme détecté → BFS retire le fond.
    ///  4. Sinon si bords surtout **clairs** (blanc / gris très clair) → 2ᵉ BFS sur moyenne des bords clairs.
    ///  5. Sinon → masque d’avant-plan Vision (instances remarquables) si le résultat est jugé fiable.
    ///  6. Sinon image inchangée.
    /// - Parameter keepSourceBackground: si `true`, pas de détourage (logo avec fond d’origine) — utile visibilité sur planche claire.
    static func imageForFlyerLogoExport(_ image: UIImage, keepSourceBackground: Bool = false) -> UIImage {
        guard let resized = image.flyerResizedMaxSide(FlyerLogoExportConfig.maxSideBeforeMask) else {
            return image
        }
        if keepSourceBackground { return resized }
        // Ancien test (> 5 % alpha < 128) faisait sauter **tout** le détourage sur beaucoup d’actifs
        // (HEIC, exports avec léger bruit alpha) : le fond blanc restait.
        if isAlreadyRealTransparentCutout(resized) {
            return resized
        }
        let toMask: UIImage
        if shouldFlattenDubiousAlphaToOpaqueOnWhite(resized) {
            toMask = renderOpaqueCompositedOnWhite(resized) ?? resized
        } else {
            toMask = resized
        }
        if let u = removeUniformBackgroundFromEdges(from: toMask) { return u }
        if let l = removeLightBackgroundFromEdges(from: toMask) { return l }
        if let v = removeBackgroundForegroundInstanceMask(from: toMask) { return v }
        if let g = removeUniformBackgroundGlobalMatchingEdgeColor(from: toMask) { return g }
        if let p = removeFlatLightPaperColorGlobally(from: toMask) { return p }
        return toMask
    }

    // MARK: - Vérification transparence existante

    /// Découpe déjà nette (PNG avec **vrais** trous) : on n’enlève pas le détourage — seulement un léger « punch »
    /// des blancs 255/255/255 opaques résiduels. Ne pas confondre avec 5 % de semi-transparence (bruit).
    private static func isAlreadyRealTransparentCutout(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let alpha = cg.alphaInfo
        let hasChannel = alpha != .none && alpha != .noneSkipFirst && alpha != .noneSkipLast
        guard hasChannel else { return false }
        let side = 128
        var buf = Data(count: side * side * 4)
        return buf.withUnsafeMutableBytes { raw -> Bool in
            guard let ptr = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            guard let ctx = CGContext(
                data: ptr, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
            ) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            let nPix = side * side
            var strongClear = 0
            for i in 0..<nPix {
                if ptr[i * 4 + 3] < 40 { strongClear += 1 }
            }
            return strongClear > (nPix * 9) / 100
        }
    }

    // MARK: - Alpha bruité (HEIC / exports) : aplatir sur blanc opaq. pour que BFS re-voie un fond net

    private static func shouldFlattenDubiousAlphaToOpaqueOnWhite(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let alpha = cg.alphaInfo
        guard alpha != .none, alpha != .noneSkipLast, alpha != .noneSkipFirst else { return false }
        let side = 128
        var buf = Data(count: side * side * 4)
        return buf.withUnsafeMutableBytes { raw -> Bool in
            guard let ptr = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            guard let ctx = CGContext(
                data: ptr, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
            ) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            let n = side * side
            var inBetween = 0
            for i in 0..<n {
                let a = ptr[i * 4 + 3]
                if a > 12 && a < 252 { inBetween += 1 }
            }
            return inBetween > n / 400 && inBetween < n * 9 / 100
        }
    }

    private static func renderOpaqueCompositedOnWhite(_ image: UIImage) -> UIImage? {
        let s = image.size
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.opaque = true
        fmt.scale = image.scale
        let r = UIGraphicsImageRenderer(size: s, format: fmt)
        return r.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: s))
            image.draw(in: CGRect(origin: .zero, size: s))
        }
    }

    // MARK: - Suppression du fond uniforme

    /// Retire les pixels de fond si le fond est uniforme (couleur estimée par histogramme
    /// sur tous les pixels de bord, vérifiée sur ces mêmes pixels).
    /// Si le fond n'est pas uniforme → nil (pas de modification).
    private static func removeUniformBackgroundFromEdges(from image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w >= 8, h >= 8 else { return nil }

        let bpp = 4
        let bpr = w * bpp
        var data = Data(count: h * bpr)

        return data.withUnsafeMutableBytes { raw -> UIImage? in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            guard let ctx = CGContext(
                data: base, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
            ) else { return nil }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

            let tol = 58  // tolérance par canal (absorbe artefacts JPEG, anti-aliasing, légères variations)

            // ── 1. Couleur de fond : couleur dominante parmi tous les pixels de bord ─
            // On échantillonne TOUS les pixels du bord (pas seulement les 4 coins) pour
            // trouver le groupe de couleur le plus fréquent. Robuste aux logos qui ont
            // des éléments colorés exactement aux coins.
            var edgePixels: [(r: Int, g: Int, b: Int)] = []
            edgePixels.reserveCapacity(2 * (w + h))
            func collectEdge(_ x: Int, _ y: Int) {
                let o = (y * w + x) * bpp
                edgePixels.append((Int(base[o]), Int(base[o + 1]), Int(base[o + 2])))
            }
            for x in 0..<w { collectEdge(x, 0); collectEdge(x, h - 1) }
            for y in 1..<(h - 1) { collectEdge(0, y); collectEdge(w - 1, y) }

            // Trouve la couleur dominante par vote : chaque pixel vote pour le premier
            // centroïde (groupe) dans la tolérance, sinon crée un nouveau centroïde.
            var centroids: [(r: Int, g: Int, b: Int, count: Int)] = []
            for px in edgePixels {
                var placed = false
                for i in 0..<centroids.count {
                    let c = centroids[i]
                    if abs(px.r - c.r) <= tol && abs(px.g - c.g) <= tol && abs(px.b - c.b) <= tol {
                        // Met à jour le centroïde par moyenne cumulative
                        let n = c.count + 1
                        centroids[i] = (
                            r: (c.r * c.count + px.r) / n,
                            g: (c.g * c.count + px.g) / n,
                            b: (c.b * c.count + px.b) / n,
                            count: n
                        )
                        placed = true
                        break
                    }
                }
                if !placed { centroids.append((px.r, px.g, px.b, 1)) }
            }
            guard let best = centroids.max(by: { $0.count < $1.count }) else { return nil }
            let bgR = best.r, bgG = best.g, bgB = best.b

            // ── 2. Uniformité : au moins 50 % des pixels de bord appartiennent au fond ─
            func isBg(_ idx: Int) -> Bool {
                let o = idx * bpp
                return abs(Int(base[o])     - bgR) <= tol
                    && abs(Int(base[o + 1]) - bgG) <= tol
                    && abs(Int(base[o + 2]) - bgB) <= tol
            }

            let total = edgePixels.count
            var matched = 0
            for x in 0..<w {
                if isBg(0 * w + x)       { matched += 1 }
                if isBg((h - 1) * w + x) { matched += 1 }
            }
            for y in 1..<(h - 1) {
                if isBg(y * w + 0)       { matched += 1 }
                if isBg(y * w + (w - 1)) { matched += 1 }
            }

            // Fond non uniforme (photo, scène complexe) → ne pas toucher.
            // Seuil assoupli: certains logos JPEG/PNG ont des bords légèrement bruités.
            guard Double(matched) / Double(max(1, total)) >= 0.35 else { return nil }

            // ── 3. BFS depuis tous les pixels de bord qui appartiennent au fond ──────
            var visited = [Bool](repeating: false, count: w * h)
            var queue = [Int]()
            queue.reserveCapacity(min(w * h / 4, 100_000))

            func tryEnqueue(_ x: Int, _ y: Int) {
                guard x >= 0, x < w, y >= 0, y < h else { return }
                let i = y * w + x
                guard !visited[i], isBg(i) else { return }
                visited[i] = true
                queue.append(i)
            }

            for x in 0..<w { tryEnqueue(x, 0); tryEnqueue(x, h - 1) }
            for y in 1..<(h - 1) { tryEnqueue(0, y); tryEnqueue(w - 1, y) }

            var q = 0
            while q < queue.count {
                let i = queue[q]; q += 1
                let x = i % w, y = i / w
                tryEnqueue(x + 1, y); tryEnqueue(x - 1, y)
                tryEnqueue(x, y + 1); tryEnqueue(x, y - 1)
            }

            // ── 3b. Contreformes (trous dans les lettres) ──────────────────────────────
            // Le BFS depuis le bord ne traverse pas le trait du logo : une zone de la couleur
            // du fond entièrement entourée par le sujet reste « non visitée ». On retire aussi
            // ces composantes connexes (même critère isBg, 4-voisinage).
            var shouldClear = visited
            var cavitySeen = [Bool](repeating: false, count: w * h)

            for start in 0..<(w * h) {
                guard !visited[start], !cavitySeen[start], isBg(start) else { continue }
                var stack: [Int] = [start]
                cavitySeen[start] = true
                while let i = stack.popLast() {
                    shouldClear[i] = true
                    let x = i % w
                    let y = i / w
                    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                        let nx = x + dx
                        let ny = y + dy
                        guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                        let ni = ny * w + nx
                        guard !visited[ni], !cavitySeen[ni], isBg(ni) else { continue }
                        cavitySeen[ni] = true
                        stack.append(ni)
                    }
                }
            }

            var clearCount = 0
            for i in 0..<(w * h) where shouldClear[i] { clearCount += 1 }
            let keepCount = w * h - clearCount
            if keepCount < max(8, (w * h) / 5_000) { return nil }

            // ── 4. Effacer les pixels de fond (alpha = 0) ─────────────────────────────
            for i in 0..<(w * h) where shouldClear[i] {
                let o = i * bpp
                base[o] = 0; base[o + 1] = 0; base[o + 2] = 0; base[o + 3] = 0
            }

            guard let outCg = ctx.makeImage() else { return nil }
            let outUi = UIImage(cgImage: outCg, scale: image.scale, orientation: image.imageOrientation)
            return outUi
        }
    }

    // MARK: - Fond blanc / gris très clair (2ᵉ stratégie)

    private static func isLightishFloodableEdgePixel(r: Int, g: Int, b: Int) -> Bool {
        let mn = min(r, g, b)
        let mx = max(r, g, b)
        if mn >= 198 && (mx - mn) <= 55 { return true }
        if r + g + b > 610 && (mx - mn) <= 72 { return true }
        return false
    }

    /// Même principe que le BFS sur couleur dominante, mais cible explicitement un fond **clair** (logos scannés,
    /// photos avec bruit de bord, JPEG : le vote « une seule couleur » échoue alors que 30 %+ du bord est blanc).
    private static func removeLightBackgroundFromEdges(from image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w >= 8, h >= 8 else { return nil }

        let bpp = 4
        let bpr = w * bpp
        var data = Data(count: h * bpr)

        return data.withUnsafeMutableBytes { raw -> UIImage? in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            guard let ctx = CGContext(
                data: base, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
            ) else { return nil }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

            let tol = 58

            var edgePixels: [(r: Int, g: Int, b: Int)] = []
            edgePixels.reserveCapacity(2 * (w + h))
            func collectEdge(_ x: Int, _ y: Int) {
                let o = (y * w + x) * bpp
                edgePixels.append((Int(base[o]), Int(base[o + 1]), Int(base[o + 2])))
            }
            for x in 0..<w { collectEdge(x, 0); collectEdge(x, h - 1) }
            for y in 1..<(h - 1) { collectEdge(0, y); collectEdge(w - 1, y) }

            var lr = 0, lg = 0, lb = 0, ln = 0
            for px in edgePixels {
                let r = px.r, g = px.g, b = px.b
                if isLightishFloodableEdgePixel(r: r, g: g, b: b) {
                    lr += r
                    lg += g
                    lb += b
                    ln += 1
                }
            }
            guard ln >= max(6, edgePixels.count * 25 / 100) else { return nil }
            let bgR = lr / ln
            let bgG = lg / ln
            let bgB = lb / ln

            func isBg(_ idx: Int) -> Bool {
                let o = idx * bpp
                let r = Int(base[o])
                let g = Int(base[o + 1])
                let b = Int(base[o + 2])
                if r + g + b < 455 { return false }
                return abs(r - bgR) <= tol && abs(g - bgG) <= tol && abs(b - bgB) <= tol
            }

            let total = edgePixels.count
            var matched = 0
            for x in 0..<w {
                if isBg(0 * w + x) { matched += 1 }
                if isBg((h - 1) * w + x) { matched += 1 }
            }
            for y in 1..<(h - 1) {
                if isBg(y * w + 0) { matched += 1 }
                if isBg(y * w + (w - 1)) { matched += 1 }
            }
            guard Double(matched) / Double(max(1, total)) >= 0.28 else { return nil }

            var visited = [Bool](repeating: false, count: w * h)
            var queue = [Int]()
            queue.reserveCapacity(min(w * h / 4, 100_000))

            func tryEnqueue(_ x: Int, _ y: Int) {
                guard x >= 0, x < w, y >= 0, y < h else { return }
                let i = y * w + x
                guard !visited[i], isBg(i) else { return }
                visited[i] = true
                queue.append(i)
            }

            for x in 0..<w { tryEnqueue(x, 0); tryEnqueue(x, h - 1) }
            for y in 1..<(h - 1) { tryEnqueue(0, y); tryEnqueue(w - 1, y) }

            var q = 0
            while q < queue.count {
                let i = queue[q]
                q += 1
                let x = i % w
                let y = i / w
                tryEnqueue(x + 1, y)
                tryEnqueue(x - 1, y)
                tryEnqueue(x, y + 1)
                tryEnqueue(x, y - 1)
            }

            var shouldClear = visited
            var cavitySeen = [Bool](repeating: false, count: w * h)

            for start in 0..<(w * h) {
                guard !visited[start], !cavitySeen[start], isBg(start) else { continue }
                var stack: [Int] = [start]
                cavitySeen[start] = true
                while let i = stack.popLast() {
                    shouldClear[i] = true
                    let x = i % w
                    let y = i / w
                    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                        let nx = x + dx
                        let ny = y + dy
                        guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                        let ni = ny * w + nx
                        guard !visited[ni], !cavitySeen[ni], isBg(ni) else { continue }
                        cavitySeen[ni] = true
                        stack.append(ni)
                    }
                }
            }

            var kept = 0
            for i in 0..<(w * h) where !shouldClear[i] {
                kept += 1
            }
            guard Double(kept) / Double(w * h) > 0.0025 else { return nil }

            for i in 0..<(w * h) where shouldClear[i] {
                let o = i * bpp
                base[o] = 0
                base[o + 1] = 0
                base[o + 2] = 0
                base[o + 3] = 0
            }

            guard let outCg = ctx.makeImage() else { return nil }
            return UIImage(cgImage: outCg, scale: image.scale, orientation: image.imageOrientation)
        }
    }

    // MARK: - Fond = couleur bords **partout** (quand BFS n’y arrive pas : fond blanc entouré par le sujet)

    /// Même couleur dominante de bord que le BFS, mais efface **tous** les pixels de cette couleur
    /// (même cavités, îlots) — dès qu’environ 20 % du bord l’admet et le fond est clair.
    private static func removeUniformBackgroundGlobalMatchingEdgeColor(from image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w >= 6, h >= 6 else { return nil }
        let bpp = 4
        let bpr = w * bpp
        var data = Data(count: h * bpr)
        return data.withUnsafeMutableBytes { raw -> UIImage? in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            guard let ctx = CGContext(
                data: base, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
            ) else { return nil }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            let tol = 64
            var edgeCoords: [(Int, Int)] = []
            for x in 0..<w { edgeCoords.append((x, 0)); edgeCoords.append((x, h - 1)) }
            for y in 1..<(h - 1) { edgeCoords.append((0, y)); edgeCoords.append((w - 1, y)) }
            var centroids: [(r: Int, g: Int, b: Int, count: Int)] = []
            for p in edgeCoords {
                let o = (p.1 * w + p.0) * bpp
                let px = (Int(base[o]), Int(base[o + 1]), Int(base[o + 2]))
                var placed = false
                for i in 0..<centroids.count {
                    let c = centroids[i]
                    if abs(px.0 - c.r) <= tol, abs(px.1 - c.g) <= tol, abs(px.2 - c.b) <= tol {
                        let n = c.count + 1
                        centroids[i] = (r: (c.r * c.count + px.0) / n, g: (c.g * c.count + px.1) / n, b: (c.b * c.count + px.2) / n, count: n)
                        placed = true
                        break
                    }
                }
                if !placed { centroids.append((px.0, px.1, px.2, 1)) }
            }
            guard let best = centroids.max(by: { $0.count < $1.count }) else { return nil }
            let bgR = best.r, bgG = best.g, bgB = best.b
            if bgR + bgG + bgB < 410 { return nil }
            let total = 2 * w + 2 * h - 4
            var matched = 0
            func isBg(_ i: Int) -> Bool {
                let o = i * bpp
                return abs(Int(base[o]) - bgR) <= tol
                    && abs(Int(base[o + 1]) - bgG) <= tol
                    && abs(Int(base[o + 2]) - bgB) <= tol
            }
            for x in 0..<w {
                if isBg(0 * w + x) { matched += 1 }
                if isBg((h - 1) * w + x) { matched += 1 }
            }
            for y in 1..<(h - 1) {
                if isBg(y * w) { matched += 1 }
                if isBg(y * w + (w - 1)) { matched += 1 }
            }
            guard Double(matched) / Double(max(1, total)) >= 0.20 else { return nil }
            var cleared = 0
            for i in 0..<(w * h) where isBg(i) {
                cleared += 1
            }
            let keep = w * h - cleared
            if keep < max(8, (w * h) / 5_000) { return nil }
            for i in 0..<(w * h) where isBg(i) {
                let o = i * bpp
                base[o] = 0; base[o + 1] = 0; base[o + 2] = 0; base[o + 3] = 0
            }
            guard let out = ctx.makeImage() else { return nil }
            return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
        }
    }

    /// Dernier recours : « papier » blanc / gris très plat (souvent ce qui reste après JPEG côté export).
    private static func removeFlatLightPaperColorGlobally(from image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w >= 4, h >= 4 else { return nil }
        let bpp = 4
        let bpr = w * bpp
        var data = Data(count: h * bpr)
        return data.withUnsafeMutableBytes { raw -> UIImage? in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            guard let ctx = CGContext(
                data: base, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
            ) else { return nil }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            var nFlat = 0
            for i in 0..<(w * h) {
                let o = i * bpp
                let r = Int(base[o]), g = Int(base[o + 1]), b = Int(base[o + 2])
                let a = Int(base[o + 3])
                guard a > 8 else { continue }
                let mx = max(r, g, b), mn = min(r, g, b)
                if r + g + b >= 718 && (mx - mn) <= 14 { nFlat += 1 }
            }
            guard Double(nFlat) / Double(w * h) > 0.04 else { return nil }
            var postKeep = 0
            for i in 0..<(w * h) {
                let o = i * bpp
                let r = Int(base[o]), g = Int(base[o + 1]), b = Int(base[o + 2])
                let a = Int(base[o + 3])
                if a <= 8 { postKeep += 1; continue }
                let mx = max(r, g, b), mn = min(r, g, b)
                if r + g + b >= 718 && (mx - mn) <= 14 {
                    base[o] = 0; base[o + 1] = 0; base[o + 2] = 0; base[o + 3] = 0
                } else { postKeep += 1 }
            }
            if postKeep < max(8, (w * h) / 5_000) { return nil }
            guard let out = ctx.makeImage() else { return nil }
            return UIImage(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
        }
    }

    // MARK: - Vision (fond non uniforme, iOS 17+)

    private static let visionCIContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .cacheIntermediates: true
    ])

    private static func imageOrientationNormalizedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let r = UIGraphicsImageRenderer(size: image.size, format: format)
        return r.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }

    /// Masque d’instance d’avant-plan (sujet « remarquable ») lorsque le fond n’est pas détectable comme couleur unique.
    private static func removeBackgroundForegroundInstanceMask(from image: UIImage) -> UIImage? {
        let flat = imageOrientationNormalizedUp(image)
        guard let cgImage = flat.cgImage else { return nil }
        let w = cgImage.width, h = cgImage.height
        guard w >= 32, h >= 32 else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let obs = request.results?.first as? VNInstanceMaskObservation else { return nil }
        let set = obs.allInstances
        guard !set.isEmpty else { return nil }
        let buffer: CVPixelBuffer
        do {
            buffer = try obs.generateMaskedImage(
                ofInstances: set,
                from: handler,
                croppedToInstancesExtent: false
            )
        } catch {
            return nil
        }
        guard visionMaskedBufferPassesHeuristic(buffer) else { return nil }
        let ci = CIImage(cvPixelBuffer: buffer)
        let extent = ci.extent
        guard extent.width >= 1, extent.height >= 1 else { return nil }
        guard let outCg = visionCIContext.createCGImage(ci, from: extent) else { return nil }
        return UIImage(cgImage: outCg, scale: flat.scale, orientation: .up)
    }

    /// Évite d’accepter un masque entièrement plein, entièrement troué, ou sans premier plan / sans transparence utile.
    private static func visionMaskedBufferPassesHeuristic(_ buffer: CVPixelBuffer) -> Bool {
        let ci = CIImage(cvPixelBuffer: buffer)
        let ext = ci.extent
        let extW = ext.width
        let extH = ext.height
        guard extW >= 1, extH >= 1 else { return false }
        let maxSide: CGFloat = 256
        let s = min(1, min(maxSide / extW, maxSide / extH))
        let w = max(1, Int(ceil(extW * s)))
        let h = max(1, Int(ceil(extH * s)))
        let n = w * h
        var data = [UInt8](repeating: 0, count: n * 4)
        let rowB = w * 4
        let cs = CGColorSpaceCreateDeviceRGB()
        return data.withUnsafeMutableBytes { raw -> Bool in
            guard let ptr = raw.baseAddress else { return false }
            visionCIContext.render(
                ci,
                toBitmap: ptr,
                rowBytes: rowB,
                bounds: ext,
                format: .RGBA8,
                colorSpace: cs
            )
            let b = raw.bindMemory(to: UInt8.self)
            var transparent = 0
            var strongFg = 0
            for i in 0..<n {
                let a = b[i * 4 + 3]
                if a < 18 { transparent += 1 }
                if a > 210 { strongFg += 1 }
            }
            if transparent < 1 { return false }
            if strongFg < 1 { return false }
            if Double(transparent) / Double(n) > 0.999 { return false }
            return true
        }
    }

    /// Luminance relative sRGB moyenne (0–1) des pixels visibles, RGB dé-premultipliés.
    private static func meanRelativeLuminanceOfOpaquePixels(
        premultipliedRGBA: Data,
        w: Int,
        h: Int,
        bpp: Int
    ) -> Double? {
        return premultipliedRGBA.withUnsafeBytes { raw -> Double? in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            var sum = 0.0
            var n = 0
            let count = w * h
            for i in 0..<count {
                let o = i * bpp
                let ap = Double(base[o + 3]) / 255.0
                if ap < 0.08 { continue }
                let rp = Double(base[o]) / 255.0
                let gp = Double(base[o + 1]) / 255.0
                let bp = Double(base[o + 2]) / 255.0
                let r = min(1, rp / ap)
                let g = min(1, gp / ap)
                let b = min(1, bp / ap)
                let l = 0.2126 * srgbToLinearish(r) + 0.7152 * srgbToLinearish(g) + 0.0722 * srgbToLinearish(b)
                sum += l
                n += 1
            }
            guard n > 8 else { return nil }
            return sum / Double(n)
        }
    }

    private static func srgbToLinearish(_ c: Double) -> Double {
        c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
}

// MARK: - Config

private enum FlyerLogoExportConfig {
    /// Taille max avant traitement — assez grand pour rendu net, assez petit pour l'API.
    static let maxSideBeforeMask: CGFloat = 1536
}

// MARK: - UIImage extensions

extension UIImage {
    /// Exporte le logo préparé (fond retiré si uniforme) en PNG data URL.
    /// Réduit progressivement jusqu'à tenir dans maxEncodedLength octets UTF-8.
    func flyerLogoPNGDataURLForAI(
        maxEncodedLength: Int = 2_400_000,
        keepSourceBackground: Bool = false
    ) -> String? {
        let prepared = FlyerLogoBackgroundPrepared.imageForFlyerLogoExport(self, keepSourceBackground: keepSourceBackground)
        let pngSides: [CGFloat] = [1536, 1280, 1024, 896, 768, 640, 512, 384, 320, 256, 220, 180, 160, 128]
        let maxIn = max(prepared.size.width, prepared.size.height)
        for maxSide in pngSides {
            let scale = min(1.0, maxSide / max(1, maxIn))
            let w = prepared.size.width * scale
            let h = prepared.size.height * scale
            let fmt = UIGraphicsImageRendererFormat.default()
            fmt.opaque = false
            fmt.scale = prepared.scale
            let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt)
                .image { _ in prepared.draw(in: CGRect(origin: .zero, size: CGSize(width: w, height: h))) }
            if let data = img.pngData() {
                let b64 = data.base64EncodedString()
                let url = "data:image/png;base64,\(b64)"
                if url.utf8.count <= maxEncodedLength { return url }
            }
        }
        // Détourage actif : la transparence ne doit jamais passer en JPEG (le JPEG réintroduit un fond plein opaqué).
        guard keepSourceBackground else { return nil }

        // Avec le fond d’origine : JPEG progressif (plafond **UTF-8** chaîne data URL).
        let jpegSides: [CGFloat] = [512, 420, 360, 300, 256, 220, 180, 160, 128, 112, 96]
        let qualities: [CGFloat] = [0.82, 0.72, 0.62, 0.52, 0.44, 0.36, 0.30, 0.24]
        for maxSide in jpegSides {
            let scale = min(1.0, maxSide / max(1, maxIn))
            let w = prepared.size.width * scale
            let h = prepared.size.height * scale
            let fmt = UIGraphicsImageRendererFormat.default()
            fmt.opaque = false
            fmt.scale = prepared.scale
            let img = UIGraphicsImageRenderer(size: CGSize(width: max(1, w), height: max(1, h)), format: fmt)
                .image { _ in prepared.draw(in: CGRect(origin: .zero, size: CGSize(width: w, height: h))) }
            for q in qualities {
                if let data = img.jpegData(compressionQuality: q) {
                    let url = "data:image/jpeg;base64,\(data.base64EncodedString())"
                    if url.utf8.count <= maxEncodedLength { return url }
                }
            }
        }
        return nil
    }

    /// Tente d’abord toutes les réductions PNG possibles (logo détouré) avant tout repli JPEG côté appelant.
    /// Utilisé quand `flyerLogoPNGDataURLForAI` a échoué faute de place, mais l’image porte de la transparence.
    func flyerFittingPngDataURLForTransparencyTight(maxEncodedLength: Int) -> String? {
        let maxIn = max(self.size.width, self.size.height)
        let extraSides: [CGFloat] = [
            400, 352, 304, 272, 240, 208, 192, 176, 128, 112, 100, 88, 80, 72, 64, 56, 48, 40, 32, 28, 24, 20, 16
        ]
        for maxSide in extraSides {
            let scale = min(1.0, maxSide / max(1, maxIn))
            let w = self.size.width * scale
            let h = self.size.height * scale
            let fmt = UIGraphicsImageRendererFormat.default()
            fmt.opaque = false
            fmt.scale = self.scale
            let img = UIGraphicsImageRenderer(size: CGSize(width: max(1, w), height: max(1, h)), format: fmt)
                .image { _ in self.draw(in: CGRect(origin: .zero, size: CGSize(width: w, height: h))) }
            if let data = img.pngData() {
                let b64 = data.base64EncodedString()
                let url = "data:image/png;base64,\(b64)"
                if url.utf8.count <= maxEncodedLength { return url }
            }
        }
        return nil
    }

    /// Vrai si le bitmap peut comporter de la transparence (détourage, etc.) : évite de repasser en JPEG
    /// si un pixel est semi-transparent, auquel cas le JPEG tuerait l’incrustation.
    var flyerImageLikelyHasTransparency: Bool {
        guard let ci = self.cgImage else { return false }
        let ai = ci.alphaInfo
        if ai == .first || ai == .last || ai == .alphaOnly { return true }
        if ai == .none || ai == .noneSkipLast || ai == .noneSkipFirst { return false }
        return flyerExtensionSampleHasAnyNonOpaque()
    }

    private func flyerExtensionSampleHasAnyNonOpaque() -> Bool {
        let side = 64
        var buf = Data(count: side * side * 4)
        return buf.withUnsafeMutableBytes { raw -> Bool in
            guard let ptr = raw.bindMemory(to: UInt8.self).baseAddress,
                  let cgi = self.cgImage,
                  let ctx = CGContext(
                      data: ptr, width: side, height: side, bitsPerComponent: 8,
                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return true }
            ctx.draw(cgi, in: CGRect(x: 0, y: 0, width: side, height: side))
            for i in 0..<(side * side) where ptr[i * 4 + 3] < 255 {
                return true
            }
            return false
        }
    }

    fileprivate func flyerResizedMaxSide(_ maxSide: CGFloat) -> UIImage? {
        let m = max(size.width, size.height)
        guard m > maxSide else { return self }
        let s = maxSide / m
        let newSize = CGSize(width: size.width * s, height: size.height * s)
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.opaque = false
        fmt.scale = scale
        return UIGraphicsImageRenderer(size: newSize, format: fmt)
            .image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
