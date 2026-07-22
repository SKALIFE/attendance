#!/usr/bin/env bash
#
# SKALA Attendance 앱 아이콘 생성 스크립트
#
# PRODUCT_SPEC.md 아이콘 원칙:
#   - 체크 표시, 출입구, 작은 모바일 창의 추상적 조합
#   - SK 또는 SKALA 공식 로고를 복제하지 않음
#   - 아이콘 세트 생성 절차를 저장소에 포함
#
# 이 스크립트는 Swift 스크립트로 CoreGraphics를 사용해
# macOS AppIcon.appiconset에 필요한 PNG들을 생성한다.
# 생성된 .iconset은 iconutil로 .icns로 변환한다.
#
# 사용법:
#   scripts/generate-icon.sh
#
# 출력:
#   SKALAAttendance/Resources/AppIcon.iconset/*.png
#   SKALAAttendance/Resources/AppIcon.icns (iconutil 변환 후)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET_DIR="$REPO_ROOT/build/icon-render/AppIcon.iconset"
ICNS_OUTPUT="$REPO_ROOT/SKALAAttendance/Resources/AppIcon.icns"
SCRIPT_PATH="$REPO_ROOT/build/icon-render/icon-render.swift"

mkdir -p "$ICONSET_DIR"

cat > "$SCRIPT_PATH" <<'SWIFT'
// SKALA Attendance 아이콘 렌더러
// 추상적 체크/출입구/모바일 창 조합을 CoreGraphics로 그린다.
import AppKit
import CoreGraphics

func renderIcon(size: CGFloat) -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return Data() }

    // 배경: 둥근 사각형 그라데이션
    let bgRect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.22
    let bgPath = CGPath(
        roundedRect: bgRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )
    ctx.addPath(bgPath)
    ctx.clip()

    // 그라데이션 배경
    let colors = [
        CGColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 1.0),
        CGColor(red: 0.10, green: 0.30, blue: 0.65, alpha: 1.0)
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: colors,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    // 모바일 창 윤곽 (출입구 추상)
    let phoneW = size * 0.42
    let phoneH = size * 0.62
    let phoneX = (size - phoneW) / 2
    let phoneY = (size - phoneH) / 2
    let phoneRect = CGRect(x: phoneX, y: phoneY, width: phoneW, height: phoneH)
    let phoneRadius = size * 0.05
    let phonePath = CGPath(
        roundedRect: phoneRect,
        cornerWidth: phoneRadius,
        cornerHeight: phoneRadius,
        transform: nil
    )
    ctx.addPath(phonePath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    ctx.setLineWidth(size * 0.025)
    ctx.strokePath()

    // 체크 표시
    let checkScale = size * 0.3
    let cx = size / 2
    let cy = size / 2
    ctx.setStrokeColor(CGColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0))
    ctx.setLineWidth(size * 0.05)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let check = CGMutablePath()
    check.move(to: CGPoint(x: cx - checkScale * 0.4, y: cy))
    check.addLine(to: CGPoint(x: cx - checkScale * 0.1, y: cy - checkScale * 0.35))
    check.addLine(to: CGPoint(x: cx + checkScale * 0.45, y: cy + checkScale * 0.35))
    ctx.addPath(check)
    ctx.strokePath()

    guard let cgImage = ctx.makeImage() else { return Data() }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    return bitmap.representation(using: .png, properties: [:]) ?? Data()
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let fm = FileManager.default

// macOS AppIcon에 필요한 크기들
let sizes: [(name: String, px: CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

for entry in sizes {
    let pngData = renderIcon(size: entry.px)
    let outURL = URL(fileURLWithPath: outputDir).appendingPathComponent("\(entry.name).png")
    try? pngData.write(to: outURL)
}

print("Generated \(sizes.count) icon PNGs in \(outputDir)")
SWIFT

echo "Rendering icon PNGs..."
swift "$SCRIPT_PATH" "$ICONSET_DIR"

echo "Converting to .icns..."
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUTPUT" 2>/dev/null || {
    echo "Note: iconutil not available or conversion skipped. PNG iconset remains at $ICONSET_DIR"
}

echo "Done. Icon ICNS generated at: $ICNS_OUTPUT"
echo "Intermediate iconset at: $ICONSET_DIR"
