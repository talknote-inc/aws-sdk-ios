//
//  AWSMobile+Talknote.swift
//  AWSMobileClient
//
//  Created by Daisuke Kubota on 2021/11/12.
//

import Foundation
import AWSCore

extension AWSMobileClient {
    func cognitoCredentialsProvider() -> AWSCognitoCredentialsProvider? {
        if let name = name {
            let rootInfoDictionary = AWSInfo.default().rootInfoDictionary
            let rootCredentialsProvider = rootInfoDictionary["CredentialsProvider"] as? [String: Any]
            let cognitoIndetity = rootCredentialsProvider?["CognitoIdentity"] as? [String: Any]
            let defaultCredentialsProviderDictionary = cognitoIndetity?["Default"] as? [String: Any]
            let regionType = defaultCredentialsProviderDictionary?["Region"] as! String

            let keychainDictionary = rootInfoDictionary["Keychain"] as? [String: Any]
            let keychainService = keychainDictionary?["Service"] as? String
            let keychainAccessGroup = keychainDictionary?["AccessGroup"] as? String

            return AWSCognitoCredentialsProvider(
                regionType: regionType.regionTypeValue(),
                identityPoolId: defaultCredentialsProviderDictionary?["PoolId"] as! String,
                identityProviderManager: self,
                keychainService: keychainService != nil
                    ? "\(keychainService!).\(name)" : keychainService,
                keychainAccessGroup: keychainAccessGroup
            )
        }
        return AWSInfo.default().defaultServiceInfo("IdentityManager")?.cognitoCredentialsProvider
    }
}


extension String {
    func regionTypeValue() -> AWSRegionType {
        return NSString(string: self).aws_regionTypeValue()
    }
}
