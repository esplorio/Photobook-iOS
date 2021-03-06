//
//  Modified MIT License
//
//  Copyright (c) 2010-2018 Kite Tech Ltd. https://www.kite.ly
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The software MAY ONLY be used with the Kite Tech Ltd platform and MAY NOT be modified
//  to be used with any competitor platforms. This means the software MAY NOT be modified
//  to place orders with any competitors to Kite Tech Ltd, all orders MUST go through the
//  Kite Tech Ltd platform servers.
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import XCTest
@testable import Photobook

class PhotobookTests: XCTestCase {
    
    var validDictionary = ([
        "id": 1,
        "spineTextRatio": 0.87,
        "coverLayouts": [ 9, 10 ],
        "layouts": [ 10, 11, 12, 13 ],
        "variants": [
            [
                "kiteId": "HDBOOK-127x127",
                "templateId": "hdbook_127x127",
                "name": "Square 127x127",
                "minPages": 20,
                "maxPages": 100,
                "coverSize": ["mm": ["height": 127, "width": 129]],
                "size": ["mm": ["height": 121, "width": 216]],
                "pageBleed": ["mm": 3]
            ]
        ]
    ]) as [String: AnyObject]

    func testParse_shouldSucceedWithAValidDictionary() {
        let photobook = PhotobookTemplate.parse(validDictionary)
        XCTAssertNotNil(photobook, "Parse: Should succeed with a valid dictionary")
    }

    func testParse_shouldReturnNilIfIdIsMissing() {
        var photobookDictionary = validDictionary
        photobookDictionary["id"] = nil
        
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should fail if id is missing")
    }

    func testParse_shouldReturnNilIfKiteIdIsMissing() {
        var photobookDictionary = validDictionary
        
        let invalidVariants = [
            [
                "templateId": "hdbook_127x127",
                "minPages": 20,
                "maxPages": 100,
                "coverSize": ["mm": ["height": 127, "width": 129]],
                "size": ["mm": ["height": 121, "width": 216]],
                "pageBleed": ["mm": 3]
            ]]
        
        photobookDictionary["variants"] = invalidVariants as AnyObject

        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if kite id is missing")
    }

    func testParse_shouldReturnNilIfNameIsMissing() {
        var photobookDictionary = validDictionary
        
        let invalidVariants = [
            [
                "kiteId": "HDBOOK-127x127",
                "templateId": "hdbook_127x127",
                "minPages": 20,
                "maxPages": 100,
                "coverSize": ["mm": ["height": 127, "width": 129]],
                "size": ["mm": ["height": 121, "width": 216]],
                "pageBleed": ["mm": 3]
            ]]

        photobookDictionary["variants"] = invalidVariants as AnyObject
        
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if name is missing")
    }

    // Cover Size
    func testParse_shouldReturnNilIfCoverSizeIsMissing() {
        var photobookDictionary = validDictionary
        
        let invalidVariants = [
            [   "minPages": 20,
                "maxPages": 100,
                "size": ["mm": ["height": 121, "width": 216 ]] ]]
        
        photobookDictionary["variants"] = invalidVariants as AnyObject
        
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if coverSize is missing")
    }
    
    func testParse_shouldConvertCoverSizeToPoints() {
        let photobook = PhotobookTemplate.parse(validDictionary)
        if let width = photobook?.coverSize.width, let height = photobook?.coverSize.height {
            XCTAssertTrue(width ==~ 365.66)
            XCTAssertTrue(height ==~ 360.0)
        } else {
            XCTFail("Parse: Should conver cover size to points")
        }
    }

    func testParse_shouldConvertPageSizeAndUseHalfWidth() {
        let photobook = PhotobookTemplate.parse(validDictionary)
        if let width = photobook?.pageSize.width, let height = photobook?.pageSize.height {
            XCTAssertTrue(width ==~ 306.14)
            XCTAssertTrue(height ==~ 342.99)
        } else {
            XCTFail("Parse: Should parse valid dictionary")
        }
    }

    // Page Size
    func testParse_shouldReturnNilIfSizeIsMissing() {
        var photobookDictionary = validDictionary

        let invalidVariants = [
            [
                "kiteId": "HDBOOK-127x127",
                "templateId": "hdbook_127x127",
                "minPages": 20,
                "maxPages": 100,
                "coverSize": ["mm": ["height": 127, "width": 129]],
                "pageBleed": ["mm": 3]
        ]]
        
        photobookDictionary["variants"] = invalidVariants as AnyObject
        
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if pageSize is missing")
    }
    
    // Spine Ratio
    func testParse_shouldReturnNilIfSpineRatioIsMissing() {
        var photobookDictionary = validDictionary
        photobookDictionary["spineTextRatio"] = nil
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if spineTextRatio is missing")
    }
    
    func testParse_shouldReturnNilIfSpineRatioIsZero() {
        var photobookDictionary = validDictionary
        photobookDictionary["spineTextRatio"] = 0.0 as AnyObject
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if spineTextRatio is zero")
    }

    // Layouts
    func testParse_shouldReturnNilIfCoverLayoutsIsMissing() {
        var photobookDictionary = validDictionary
        photobookDictionary["coverLayouts"] = nil
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if coverLayouts is missing")
    }
    
    func testParse_shouldReturnNilIfCoverLayoutCountIsZero() {
        var photobookDictionary = validDictionary
        photobookDictionary["coverLayouts"] = [] as AnyObject
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if the coverLayout count is zero")
    }

    func testParse_shouldReturnNilIfLayoutsIsMissing() {
        var photobookDictionary = validDictionary
        photobookDictionary["layouts"] = nil
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if layouts is missing")
    }

    func testParse_shouldReturnNilIfLayoutCountIsZero() {
        var photobookDictionary = validDictionary
        photobookDictionary["layouts"] = [] as AnyObject
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if the layout count is zero")
    }

    func testParse_shouldReturnNilIfPageBleedIsMissing() {
        var photobookDictionary = validDictionary
        
        let invalidVariants = [
            [
                "kiteId": "HDBOOK-127x127",
                "templateId": "hdbook_127x127",
                "minPages": 20,
                "maxPages": 100,
                "coverSize": ["mm": ["height": 127, "width": 129]],
                "size": ["mm": ["height": 121, "width": 216]],
            ]]
        
        photobookDictionary["variants"] = invalidVariants as AnyObject
        
        let photobookBox = PhotobookTemplate.parse(photobookDictionary)
        XCTAssertNil(photobookBox, "Parse: Should return nil if page bleed is missing")
    }
    
    func testParse_shouldConvertPageBleedToPoints() {
        let photobook = PhotobookTemplate.parse(validDictionary)
        if let pageBleed = photobook?.pageBleed {
            XCTAssertTrue(pageBleed ==~ 8.5)
        } else {
            XCTFail("Parse: Should convert page bleed to points")
        }
    }
}
