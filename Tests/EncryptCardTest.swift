//
//  EncryptTest.swift
//  
//
//  Created by Paul Zabelin on 4/30/22.
//

import XCTest
import EncryptCard

class EncryptCardTest: XCTestCase {
    var keyUrl = Bundle.module.url(forResource: "example-payment-gateway-key.txt",
                                   withExtension: nil)!
    func encryptor() throws -> EncryptCard {
        try EncryptCard(
            key: try String(contentsOf: keyUrl)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    func testEncryptString() throws {
        let encrypted = try encryptor().encrypt("sample")
        XCTAssertTrue(encrypted.hasPrefix("R1dTQ3wxfDE0MzQwf"))
    }
    func testDecodeEncrypted() throws {
        let card = CreditCard(cardNumber: "4111111111111111", expirationDate: "10/25", cvv: "123")
        let encrypted = try encryptor().encrypt(creditCard: card)
        XCTAssertTrue(encrypted.hasPrefix("R1dTQ3wxfDE0MzQwf"))
        
        let decodedData = try XCTUnwrap(Data(base64Encoded: encrypted))
        let decodedString = try XCTUnwrap(String(data: decodedData, encoding: .ascii))
        let components = decodedString.components(separatedBy: "|")
        XCTAssertEqual(6, components.count)
        XCTAssertEqual("GWSC", components[0], "format specifier")
        XCTAssertEqual("1", components[1], "version")
        XCTAssertEqual("14340", components[2], "key id")
        let encryptedAESKeyData = try XCTUnwrap(Data(base64Encoded: components[3]))
        XCTAssertEqual(256, encryptedAESKeyData.count)
        let ivData = try XCTUnwrap(Data(base64Encoded: components[4]))
        XCTAssertEqual(16, ivData.count)
        let encryptedCardData = try XCTUnwrap(Data(base64Encoded: components[5]))
        XCTAssertEqual(48, encryptedCardData.count)
    }
    func testSetKeyToValid() throws {
        let encryptor = try encryptor()
        XCTAssertEqual("14340", encryptor.keyId)
        XCTAssertEqual("www.safewebservices.com", encryptor.subject)
        XCTAssertTrue("\(encryptor.publicKey)".contains(
            "SecKeyRef algorithm id: 1, key type: RSAPublicKey, version: 4, block size: 2048 bits"
        ), "should be RSA public key 2048 bits long")
    }
    func testSetKeyInvalid() throws {
        XCTAssertThrowsError(try EncryptCard(key: "invalid"), "should be invalid") { error in
            if case let .invalidKey(message) = error as? EncryptCard.Error {
                XCTAssertEqual(message, "Key is not valid. Should start and end with '***'")
            } else {
                XCTFail("should be invalid key error")
            }
        }
    }
    func testSetKeyWithoutKeyData() throws {
        XCTAssertThrowsError(try EncryptCard(key: "***123***"), "should be invalid") { error in
            if case .invalidCertificate = error as? EncryptCard.Error {
                return
            } else {
                XCTFail("should be invalid certificate error")
            }
        }
    }
}
