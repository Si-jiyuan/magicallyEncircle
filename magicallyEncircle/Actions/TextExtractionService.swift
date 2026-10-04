//
//  TextExtractionService.swift
//  magicallyEncircle
//

import AppKit
import ApplicationServices
import Vision

/// 圈选文本提取：优先辅助功能 API（精确、快），
/// 只有当圈内元素完整落在选区内才采用；否则回退 Vision OCR。
enum TextExtractionService {
    static func extract(from image: CGImage, samplePointsInCG: [CGPoint], regionInCG: CGRect) -> String? {
        if let text = extractWithAccessibility(samplePointsInCG: samplePointsInCG, regionInCG: regionInCG), !text.isEmpty {
            return text
        }
        return recognizeText(in: image)
    }

    // MARK: - 辅助功能 API

    static func extractWithAccessibility(samplePointsInCG: [CGPoint], regionInCG: CGRect) -> String? {
        let system = AXUIElementCreateSystemWide()
        let allowedRegion = regionInCG.insetBy(dx: -6, dy: -6)
        var results: [String] = []

        for point in samplePointsInCG {
            var elementRef: AXUIElement?
            guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &elementRef) == .success,
                  let element = elementRef else { continue }

            var candidates: [AXUIElement] = [element]
            if let children = children(of: element) {
                candidates.append(contentsOf: children)
            }

            for candidate in candidates {
                guard let frame = frame(of: candidate), allowedRegion.contains(frame) else { continue }
                if let text = directTextValue(of: candidate), !text.isEmpty {
                    results.append(text)
                }
            }
        }

        var seen = Set<String>()
        let unique = results.filter { seen.insert($0).inserted }
        return unique.isEmpty ? nil : unique.joined(separator: "\n")
    }

    private static func directTextValue(of element: AXUIElement) -> String? {
        if let value = stringAttribute(element, kAXValueAttribute), !value.isEmpty {
            return value
        }
        if let selected = stringAttribute(element, kAXSelectedTextAttribute), !selected.isEmpty {
            return selected
        }
        return nil
    }

    private static func children(of element: AXUIElement) -> [AXUIElement]? {
        guard let ref = attribute(element, kAXChildrenAttribute) else { return nil }
        return ref as? [AXUIElement]
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionRef = attribute(element, kAXPositionAttribute),
              let sizeRef = attribute(element, kAXSizeAttribute),
              CFGetTypeID(positionRef) == AXValueGetTypeID(),
              CFGetTypeID(sizeRef) == AXValueGetTypeID() else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &ref) == .success else { return nil }
        return ref
    }

    private static func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    // MARK: - Vision OCR

    static func recognizeText(in image: CGImage) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results, !observations.isEmpty else { return nil }
        let sorted = observations.sorted { a, b in
            if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.02 {
                return a.boundingBox.midY > b.boundingBox.midY
            }
            return a.boundingBox.minX < b.boundingBox.minX
        }
        let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
