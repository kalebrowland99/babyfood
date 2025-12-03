import SwiftUI
import UIKit
import ImageIO

// Simple GIF player using first principles
struct StaticVideoPlayerView: UIViewRepresentable {
    let videoName: String
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        // Create UIImageView for the GIF
        let imageView = UIImageView()
        
        // Load the GIF from assets
        if let gifData = NSDataAsset(name: videoName)?.data,
           let gifImage = UIImage.gifImageWithData(gifData) {
            imageView.image = gifImage
        } else {
            // Fallback to static image if GIF fails to load
            imageView.image = UIImage(named: videoName)
        }
        
        // Set content mode to maintain aspect ratio
        imageView.contentMode = .scaleAspectFit
        
        // Calculate size based on screen width (same as original video)
        let width = UIScreen.main.bounds.width - 40
        imageView.frame = CGRect(x: 0, y: 0, width: width, height: width)
        
        // Add image view to the container view
        view.addSubview(imageView)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update frame if needed (e.g., on orientation change)
        if let imageView = uiView.subviews.first as? UIImageView {
            let width = UIScreen.main.bounds.width - 40
            imageView.frame = CGRect(x: 0, y: 0, width: width, height: width)
        }
    }
}

// Extension to handle GIF data
extension UIImage {
    static func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let count = CGImageSourceGetCount(source)
        var images = [UIImage]()
        var duration: TimeInterval = 0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: cgImage))
                
                // Get frame duration
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifInfo = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                    if let delayTime = gifInfo[kCGImagePropertyGIFDelayTime as String] as? Double {
                        duration += delayTime
                    }
                }
            }
        }
        
        if images.isEmpty {
            return nil
        }
        
        // Create animated image
        let animation = UIImage.animatedImage(with: images, duration: duration)
        return animation
    }
} 