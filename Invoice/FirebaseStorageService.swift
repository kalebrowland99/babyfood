//
//  FirebaseStorageService.swift
//  Thrifty
//
//  Firebase Storage service for uploading images and getting public URLs
//

import Foundation
import UIKit
import FirebaseStorage

class FirebaseStorageService {
    static let shared = FirebaseStorageService()
    private let storage = Storage.storage()
    
    private init() {
        // Ensure Firebase Storage is configured on the main thread to avoid CoreData issues
        if Thread.isMainThread {
            _ = Storage.storage()
        } else {
            DispatchQueue.main.sync {
                _ = Storage.storage()
            }
        }
    }
    
    /// Upload UIImage to Firebase Storage and get a public download URL
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - path: Optional custom path (defaults to thrift-images/timestamp)
    ///   - completion: Completion handler with Result containing the download URL or error
    func uploadImageForSerpAPI(
        image: UIImage,
        path: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Convert UIImage to JPEG data with compression
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(FirebaseStorageError.imageConversionFailed))
            return
        }
        
        // Generate unique filename with timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "thrift_scan_\(timestamp).jpg"
        let imagePath = path ?? "thrift-images/\(filename)"
        
        // Create storage reference
        let storageRef = storage.reference().child(imagePath)
        
        // Set metadata for better web performance
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=3600" // Cache for 1 hour
        
        // Upload the image data
        let uploadTask = storageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                print("❌ Firebase Storage upload failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("✅ Image uploaded successfully to path: \(imagePath)")
            
            // Get the download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Failed to get download URL: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(FirebaseStorageError.urlGenerationFailed))
                    return
                }
                
                let urlString = downloadURL.absoluteString
                print("🔗 Public URL generated: \(urlString)")
                completion(.success(urlString))
            }
        }
        
        // Monitor upload progress (optional)
        uploadTask.observe(.progress) { snapshot in
            guard let progress = snapshot.progress else { return }
            let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount) * 100
            print("📤 Upload progress: \(Int(percentComplete))%")
        }
        
        // Handle upload completion
        uploadTask.observe(.success) { snapshot in
            print("🎉 Upload completed successfully")
        }
        
        uploadTask.observe(.failure) { snapshot in
            if let error = snapshot.error {
                print("💥 Upload failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Async/await version of uploadImageForSerpAPI
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - path: Optional custom path
    /// - Returns: Public download URL string
    func uploadImageForSerpAPI(image: UIImage, path: String? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            uploadImageForSerpAPI(image: image, path: path) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Delete image from Firebase Storage
    /// - Parameters:
    ///   - path: Path to the image to delete
    ///   - completion: Completion handler
    func deleteImage(at path: String, completion: @escaping (Error?) -> Void) {
        let storageRef = storage.reference().child(path)
        
        storageRef.delete { error in
            if let error = error {
                print("❌ Failed to delete image at \(path): \(error.localizedDescription)")
                completion(error)
            } else {
                print("🗑️ Successfully deleted image at \(path)")
                completion(nil)
            }
        }
    }
    
    /// Get a signed URL with custom expiration (useful for temporary access)
    /// - Parameters:
    ///   - path: Path to the image
    ///   - expirationTime: Time interval for URL expiration (default: 1 hour)
    ///   - completion: Completion handler with signed URL
    func getSignedURL(
        for path: String,
        expirationTime: TimeInterval = 3600,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let storageRef = storage.reference().child(path)
        let expirationDate = Date().addingTimeInterval(expirationTime)
        
        storageRef.downloadURL { result in
            switch result {
            case .success(let url):
                completion(.success(url.absoluteString))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Custom Errors
enum FirebaseStorageError: LocalizedError {
    case imageConversionFailed
    case urlGenerationFailed
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert UIImage to JPEG data"
        case .urlGenerationFailed:
            return "Failed to generate download URL"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}

// MARK: - SerpAPI Integration Helper
extension FirebaseStorageService {
    /// Specifically formatted for SerpAPI reverse image search
    /// - Parameters:
    ///   - image: UIImage to upload for reverse search
    ///   - completion: Returns URL formatted for SerpAPI
    func uploadForReverseImageSearch(
        image: UIImage,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Use higher compression for faster uploads to SerpAPI
        uploadImageForSerpAPI(image: image, path: "serp-api/\(UUID().uuidString).jpg") { result in
            switch result {
            case .success(let url):
                print("🔍 Image ready for SerpAPI reverse search: \(url)")
                completion(.success(url))
            case .failure(let error):
                print("❌ SerpAPI upload failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Async version for SerpAPI
    func uploadForReverseImageSearch(image: UIImage) async throws -> String {
        return try await uploadImageForSerpAPI(image: image, path: "serp-api/\(UUID().uuidString).jpg")
    }
} 
