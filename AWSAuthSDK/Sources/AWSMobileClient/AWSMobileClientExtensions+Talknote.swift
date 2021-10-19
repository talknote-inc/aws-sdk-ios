//
//  AWSMobileClientExtensions+Talknote.swift
//  AWSMobileClientXCF
//
//  Created by Daisuke Kubota on 2021/09/21.
//  Copyright © 2021 Amazon Web Services. All rights reserved.
//

import Foundation

extension AWSMobileClient {
    public func getSessionBackup(completionHandler: @escaping ((String?, Error?) -> Void)) {
        switch self.federationProvider {
        case .userPools, .hostedUI:
            break
        default:
            completionHandler(nil, AWSMobileClientError.notSignedIn(message: notSignedInErrorMessage))
            return
        }
        var map = [String: Any?]()
        map["username"] = self.username
        if (self.federationProvider == .userPools) {
            map["federationProvider"] = "userPools"
            self.currentUser?.getBackup().continueWith(block: { (task) -> Any? in
                if let error = task.error {
                    completionHandler(nil, error)
                } else if let backup = task.result {
                    map["data"] = backup
                    do {
                        let data = try JSONSerialization.data(withJSONObject: map)
                        let str = String(data: data, encoding: .utf8)
                        completionHandler(str, nil)
                    } catch (let e) {
                        completionHandler(nil, e)
                    }
                }
                return nil
            })
        } else if (self.federationProvider == .hostedUI) {
            map["federationProvider"] = "hostedUI"
            print(cognitoAuthParameters)
            AWSCognitoAuth.init(forKey: CognitoAuthRegistrationKey).getBackup { (result, error) in
                if let error = error {
                    completionHandler(nil, error)
                } else if let backup = result {
                    map["data"] = backup
                    if let clientId = self.cognitoAuthParameters?.clientId {
                        map["client_id"] = clientId
                    }
                    if let clientSecret = self.cognitoAuthParameters?.clientSecret {
                        map["client_secret"] = clientSecret
                    }
                    do {
                        let data = try JSONSerialization.data(withJSONObject: map)
                        let str = String(data: data, encoding: .utf8)
                        completionHandler(str, nil)
                    } catch (let e) {
                        completionHandler(nil, e)
                    }
                }
            }
        }
    }

    public func signInWithBackup(backup: String, completionHandler: @escaping ((UserState?, Error?) -> Void)) {
        switch self.currentUserState {
        case .signedIn:
            completionHandler(nil, AWSMobileClientError.invalidState(message: "There is already a user which is signed in. Please log out the user before calling signIn."))
            return
        default:
            break
        }
        guard let backupData = backup.data(using: .utf8) else {
            completionHandler(nil, AWSMobileClientError.invalidState(message: ""))
            return
        }
        do {
            let backupJson = try JSONSerialization.jsonObject(with: backupData) as! Dictionary<String, Any?>
            let federationProvider = backupJson["federationProvider"] as? String
            if (federationProvider == "userPools") {
                self.userpoolOpsHelper.userpoolClient?.delegate = self.userpoolOpsHelper
                self.userpoolOpsHelper.authHelperDelegate = self
                let user = self.userPoolClient?.getUser(backupJson["username"] as! String)
                user!.getSession(backupJson["data"] as! Dictionary<String, String>).continueOnSuccessWith(block: { (task) -> Any? in
                    if let error = task.error {
                        self.invokeSignInCallback(signResult: nil, error: AWSMobileClientError.makeMobileClientError(from: error))
                    } else if let result = task.result {
                        self.internalCredentialsProvider?.clearCredentials()
                        self.federationProvider = .userPools
                        self.performUserPoolSuccessfulSignInTasks(session: result)
                        let tokenString = result.idToken!.tokenString
                        self.mobileClientStatusChanged(userState: .signedIn,
                                                       additionalInfo: [self.ProviderKey:self.userPoolClient!.identityProviderName,
                                                                        self.TokenKey:tokenString])
                        self.invokeSignInCallback(signResult: SignInResult(signInState: .signedIn), error: nil)
                    }
                    return nil
                })
            } else if (federationProvider == "hostedUI") {
                let hostedUIOptions = HostedUIOptions(
                    parameters: CognitoAuthParameters(
                        clientId: (backupJson["client_id"] as? String)!,
                        clientSecret: backupJson["client_secret"] as? String
                        )
                )
                configureAndRegisterCognitoAuth(
                    hostedUIOptions: hostedUIOptions,
                    completionHandler
                )
                let cognitoAuth = AWSCognitoAuth.init(forKey: CognitoAuthRegistrationKey)
                cognitoAuth.delegate = self
                cognitoAuth.signIn(withBackup: backupJson["data"] as! Dictionary<String, String>) { (session, error) in
                    self.handleCognitoAuthGetSession(hostedUIOptions: hostedUIOptions, session: session, error: error, completionHandler)
                }
            }
        } catch (let e) {
            completionHandler(nil, AWSMobileClientError.invalidState(message: e.localizedDescription))
        }

    }
}
