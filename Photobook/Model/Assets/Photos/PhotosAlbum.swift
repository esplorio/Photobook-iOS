//
//  PhotosAlbum.swift
//  Photobook
//
//  Created by Konstadinos Karayannis on 08/11/2017.
//  Copyright © 2017 Kite.ly. All rights reserved.
//

import UIKit
import Photos

protocol ChangeManager {
    func details(for fetchResult: PHFetchResult<PHAsset>) -> PHFetchResultChangeDetails<PHAsset>?
}

extension PHChange: ChangeManager {
    func details(for fetchResult: PHFetchResult<PHAsset>) -> PHFetchResultChangeDetails<PHAsset>? {
        return changeDetails(for: fetchResult)
    }
}

class PhotosAlbum: Album, Codable {
    
    let assetCollection: PHAssetCollection
    var assets = [Asset]()
    var hasMoreAssetsToLoad = false

    private var fetchedAssets: PHFetchResult<PHAsset>?
    lazy var assetManager: AssetManager = DefaultAssetManager()
    
    init(_ assetCollection: PHAssetCollection) {
        self.assetCollection = assetCollection
    }
    
    private enum CodingKeys: String, CodingKey {
        case identifier
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        let collectionId = try values.decode(String.self, forKey: .identifier)
        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionId], options: nil)
        if let assetCollection = fetchResult.firstObject {
            self.assetCollection = assetCollection
            loadAssetsFromPhotoLibrary()
            return
        }
        throw AssetLoadingException.notFound
    }

    /// Returns the estimated number of assets for this album, which might not be available without calling loadAssets. It might differ from the actual number of assets. NSNotFound if not available.
    var numberOfAssets: Int {
        return !assets.isEmpty ? assets.count : assetCollection.estimatedAssetCount
    }
    
    var localizedName: String? {
        return assetCollection.localizedTitle
    }
    
    var identifier: String {
        return assetCollection.localIdentifier
    }
    
    func loadAssets(completionHandler: ((Error?) -> Void)?) {
        DispatchQueue.global(qos: .default).async { [weak welf = self] in
            welf?.loadAssetsFromPhotoLibrary()
            DispatchQueue.main.async {
                completionHandler?(nil)
            }
        }
    }
    
    func loadAssetsFromPhotoLibrary() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.wantsIncrementalChangeDetails = true
        fetchOptions.includeHiddenAssets = false
        fetchOptions.includeAllBurstAssets = false
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: false) ]
        let fetchedAssets = assetManager.fetchAssets(in: assetCollection, options: fetchOptions)
        var assets = [Asset]()
        fetchedAssets.enumerateObjects({ (asset, _, _) in
            assets.append(PhotosAsset(asset, albumIdentifier: self.identifier))
        })
        
        self.assets = assets
        self.fetchedAssets = fetchedAssets
    }
    
    func coverAsset(completionHandler: @escaping (Asset?) -> Void) {
        assetCollection.coverAsset(useFirstImageInCollection: false, completionHandler: completionHandler)
    }
    
    func loadNextBatchOfAssets(completionHandler: ((Error?) -> Void)?) {}
    
    func changedAssets(for changeInstance: ChangeManager) -> ([Asset]?, [Asset]?) {
        guard let fetchedAssets = fetchedAssets,
            let changeDetails = changeInstance.details(for: fetchedAssets)
        else { return (nil, nil) }
        
        let insertedObjects = PhotosAsset.assets(from: changeDetails.insertedObjects, albumId: identifier)
        let removedObjects = PhotosAsset.assets(from: changeDetails.removedObjects, albumId: identifier)
        return (insertedObjects, removedObjects)
    }
}

extension PhotosAlbum: PickerAnalytics {
    var selectingPhotosScreenName: Analytics.ScreenName { return .picker }
    var addingMorePhotosScreenName: Analytics.ScreenName { return .pickerAddingMorePhotos }
}
