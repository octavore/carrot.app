import AppKit
import CoreImage
import SwiftUI

/// Blurs whatever is behind the window (the real desktop/screen contents).
/// `NSVisualEffectView` doesn't expose its blur radius, so a `CIGaussianBlur`
/// is layered on top of it to make the strength actually tunable.
struct VisualEffectBlur: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .hudWindow
  var blurRadius: CGFloat = 20

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.blendingMode = .behindWindow
    view.state = .active
    view.wantsLayer = true
    configure(view)
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    configure(nsView)
  }

  private func configure(_ view: NSVisualEffectView) {
    view.material = material
    guard let filter = CIFilter(name: "CIGaussianBlur") else { return }
    filter.setDefaults()
    filter.setValue(blurRadius, forKey: kCIInputRadiusKey)
    view.layer?.backgroundFilters = [filter]
  }
}
