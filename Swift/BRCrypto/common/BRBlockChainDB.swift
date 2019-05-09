//
//  BRBlockChainDB.swift
//  BRCrypto
//
//  Created by Ed Gamble on 3/27/19.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//  See the CONTRIBUTORS file at the project root for a list of contributors.
//

import Foundation // DispatchQueue

import BRCore
import BRCore.Ethereum

public class BlockChainDB {

    /// Base URL (String) for the BRD BlockChain DB
    let bdbBaseURL: String

    /// Base URL (String) for BRD API Services
    let apiBaseURL: String

    // The seesion to use for DataTaskFunc as in `session.dataTask (with: request, ...)`
    let session: URLSession

    /// A DispatchQueue Used for certain queries that can't be accomplished in the session's data
    /// task.  Such as when multiple request are needed in getTransactions().
    let queue = DispatchQueue.init(label: "BlockChainDB")

    /// A function type that decorates a `request`, handle 'challenges', performs decrypting and/or
    /// uncompression of response data and creates a `URLSessionDataTask` for the provided `session`.
    public typealias DataTaskFunc = (URLSession, URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask

    /// A DataTaskFunc for submission to the BRD API
    internal let apiDataTaskFunc: DataTaskFunc

    /// A DataTaskFunc for submission to the BRD BlockChain DB
    internal let bdbDataTaskFunc: DataTaskFunc

    /// A default DataTaskFunc that simply invokes `session.dataTask (with: request, ...)`
    static let defaultDataTaskFunc: DataTaskFunc = {
        (_ session: URLSession,
        _ request: URLRequest,
        _ completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask in
        session.dataTask (with: request, completionHandler: completionHandler)
    }

    ///
    /// Initialize a BlockChainDB
    ///
    /// - Parameters:
    ///   - session: the URLSession to use.  Defaults to `URLSession (configuration: .default)`
    ///   - bdbBaseURL: the baseURL for the BRD BlockChain DB.  Defaults to "http://blockchain-db.us-east-1.elasticbeanstalk.com"
    ///   - bdbDataTaskFunc: an optional DataTaskFunc for BRD BlockChain DB.  This defaults to
    ///       `session.dataTask (with: request, ...)`
    ///   - apiBaseURL: the baseRUL for the BRD API Server.  Defaults to "https://api.breadwallet.com".
    ///       if this is a DEBUG build then "https://stage2.breadwallet.com" will be used instead.
    ///   - apiDataTaskFunc: an optional DataTaskFunc for BRD API services.  For a non-DEBUG build,
    ///       this function would need to properly authenticate with BRD.  This means 'decorating
    ///       the request' header, perhaps responding to a 'challenge', perhaps decripting and/or
    ///       uncompressing response data.  This defaults to `session.dataTask (with: request, ...)`
    ///       which suffices for DEBUG builds.
    ///
    public init (session: URLSession = URLSession (configuration: .default),
                 bdbBaseURL: String = "http://blockchain-db.us-east-1.elasticbeanstalk.com",
                 bdbDataTaskFunc: DataTaskFunc? = nil,
                 apiBaseURL: String = "https://api.breadwallet.com",
                 apiDataTaskFunc: DataTaskFunc? = nil) {

        self.session = session

        self.bdbBaseURL = bdbBaseURL
        self.bdbDataTaskFunc = bdbDataTaskFunc ?? BlockChainDB.defaultDataTaskFunc

        #if DEBUG
        self.apiBaseURL = "https://stage2.breadwallet.com"
        #else
        self.ethBaseURL = apiBaseURL
        #endif
        self.apiDataTaskFunc = apiDataTaskFunc ?? BlockChainDB.defaultDataTaskFunc
    }

    ///
    /// A QueryError subtype of Error
    ///
    /// - url:
    /// - submission:
    /// - noData:
    /// - jsonParse:
    /// - model:
    /// - noEntity:
    ///
    public enum QueryError: Error {
        // HTTP URL build failed
        case url (String)

        // HTTP submission error
        case submission (Error)

        // HTTP submission didn't error but returned no data
        case noData

        // JSON parse failed, generically
        case jsonParse (Error?)

        // Could not convert JSON -> T
        case model (String)

        // JSON entity expected but not provided - e.g. requested a 'transferId' that doesn't exist.
        case noEntity (id: String?)
    }

    ///
    /// The BlockChainDB Model (aka Schema-ish)
    ///
    public struct Model {

        /// Blockchain

        public typealias Blockchain = (
            id: String,
            name: String,
            network: String,
            isMainnet: Bool,
            currency: String,
            blockHeight: UInt64 /* fee Estimate */)

        static internal func asBlockchain (json: JSON) -> Model.Blockchain? {
            guard let id = json.asString (name: "id"),
                let name = json.asString (name: "name"),
                let network = json.asString (name: "network"),
                let isMainnet = json.asBool (name: "is_mainnet"),
                let currency = json.asString (name: "native_currency_id"),
                let blockHeight = json.asUInt64 (name: "block_height")
                else { return nil }

            return (id: id, name: name, network: network, isMainnet: isMainnet, currency: currency, blockHeight: max (blockHeight, 575020))
        }

        /// We define default blockchains but these are wholly insufficient given that the
        /// specfication includes `blockHeight` (which can never be correct).
        static public let defaultBlockchains: [Blockchain] = [
            // Mainnet
 //           (id: "bitcoin-mainnet",  name: "Bitcoin",  network: "mainnet", isMainnet: true,  currency: "btc", blockHeight:  600000),
            (id: "bitcash-mainnet",  name: "Bitcash",  network: "mainnet", isMainnet: true,  currency: "bch", blockHeight: 1000000),
            (id: "ethereum-mainnet", name: "Ethereum", network: "mainnet", isMainnet: true,  currency: "eth", blockHeight: 8000000),

            // Testnet
            (id: "bitcoin-testnet",  name: "Bitcoin",  network: "testnet", isMainnet: false, currency: "btc", blockHeight:  900000),
            (id: "bitcash-testnet",  name: "Bitcash",  network: "testnet", isMainnet: false, currency: "bch", blockHeight: 1200000),
            (id: "ethereum-testnet", name: "Ethereum", network: "testnet", isMainnet: false, currency: "eth", blockHeight: 1000000),
            (id: "ethereum-rinkeby", name: "Ethereum", network: "rinkeby", isMainnet: false, currency: "eth", blockHeight: 2000000)
        ]

        /// Currency & CurrencyDenomination

        public typealias CurrencyDenomination = (name: String, code: String, decimals: UInt8, symbol: String /* extra */)
        public typealias Currency = (
            id: String,
            name: String,
            code: String,
            type: String,
            blockchainID: String,
            address: String?,
            demoninations: [CurrencyDenomination])

       static internal func asCurrencyDenomination (json: JSON) -> Model.CurrencyDenomination? {
            guard let name = json.asString (name: "name"),
                let code = json.asString (name: "short_name"),
                let decimals = json.asUInt8 (name: "decimals")
                // let symbol = json.asString (name: "symbol")
                else { return nil }

            let symbol = lookupSymbol (code)

            return (name: name, code: code, decimals: decimals, symbol: symbol)
        }

        static internal let currencySymbols = ["btc":"₿", "eth":"Ξ"]
        static internal func lookupSymbol (_ code: String) -> String {
            return currencySymbols[code] ?? code
        }

        static internal func asCurrency (json: JSON) -> Model.Currency? {
            guard // let id = json.asString (name: "id"),
                let name = json.asString (name: "name"),
                let code = json.asString (name: "code"),
                let type = json.asString (name: "type"),
                let bid  = json.asString (name: "blockchain_id")
                else { return nil }

            let id = name

            // Address is optional
            let address = json.asString(name: "address")

            // All denomincations must parse
            guard let demoninations = json.asArray (name: "denominations")?
                .map ({ JSON (dict: $0 )})
                .map ({ asCurrencyDenomination(json: $0)})
                else { return nil }
            
            return demoninations.contains (where: { nil == $0 })
                ? nil
                : (id: id, name: name, code: code, type: type, blockchainID: bid, address: address, demoninations: (demoninations as! [CurrencyDenomination]))
        }

        static public let defaultCurrencies: [Currency] = [
            // Mainnet
            (id: "Bitcoin", name: "Bitcoin", code: "btc", type: "native", blockchainID: "bitcoin-mainnet", address: nil,
             demoninations: [(name: "satoshi", code: "sat", decimals: 0, symbol: lookupSymbol ("sat")),
                             (name: "bitcoin", code: "btc", decimals: 8, symbol: lookupSymbol ("btc"))]),

            (id: "Bitcash", name: "Bitcash", code: "bch", type: "native", blockchainID: "bitcash-mainnet", address: nil,
             demoninations: [(name: "satoshi", code: "sat", decimals: 0, symbol: lookupSymbol ("sat")),
                             (name: "bitcoin", code: "bch", decimals: 8, symbol: lookupSymbol ("bch"))]),


            (id: "Ethereum", name: "Ethereum", code: "eth", type: "native", blockchainID: "ethereum-mainnet", address: nil,
             demoninations: [(name: "wei",   code: "wei",  decimals:  0, symbol: lookupSymbol ("wei")),
                             (name: "gwei",  code: "gwei", decimals:  9, symbol: lookupSymbol ("gwei")),
                             (name: "ether", code: "eth",  decimals: 18, symbol: lookupSymbol ("eth"))]),


            (id: "BRD Token", name: "BRD Token", code: "BRD", type: "erc20", blockchainID: "ethereum-mainnet", address: addressBRDMainnet,
             demoninations: [(name: "BRD_INTEGER",   code: "BRDI",  decimals:  0, symbol: "brdi"),
                             (name: "BRD",           code: "BRD",   decimals: 18, symbol: "brd")]),


            (id: "EOS Token", name: "EOS Token", code: "EOS", type: "erc20", blockchainID: "ethereum-mainnet", address: "0x86fa049857e0209aa7d9e616f7eb3b3b78ecfdb0",
             demoninations: [(name: "EOS_INTEGER",   code: "EOSI",  decimals:  0, symbol: "eosi"),
                             (name: "EOS",           code: "EOS",   decimals: 18, symbol: "eos")]),

            // Testnet
            (id: "Bitcoin-Testnet", name: "Bitcoin", code: "btc", type: "native", blockchainID: "bitcoin-testnet", address: nil,
             demoninations: [(name: "satoshi", code: "sat", decimals: 0, symbol: lookupSymbol ("sat")),
                             (name: "bitcoin", code: "btc", decimals: 8, symbol: lookupSymbol ("btc"))]),

            (id: "Bitcash-Testnet", name: "Bitcash", code: "bch", type: "native", blockchainID: "bitcash-testnet", address: nil,
             demoninations: [(name: "satoshi", code: "sat", decimals: 0, symbol: lookupSymbol ("sat")),
                             (name: "bitcoin", code: "bch", decimals: 8, symbol: lookupSymbol ("bch"))]),


            (id: "Ethereum-Testnet", name: "Ethereum", code: "eth", type: "native", blockchainID: "ethereum-testnet", address: nil,
             demoninations: [(name: "wei",   code: "wei",  decimals:  0, symbol: lookupSymbol ("wei")),
                             (name: "gwei",  code: "gwei", decimals:  9, symbol: lookupSymbol ("gwei")),
                             (name: "ether", code: "eth",  decimals: 18, symbol: lookupSymbol ("eth"))]),

            (id: "BRD Token Testnet", name: "BRD Token", code: "BRD", type: "erc20", blockchainID: "ethereum-testnet", address: addressBRDTestnet,
             demoninations: [(name: "BRD_INTEGER",   code: "BRDI",  decimals:  0, symbol: "brdi"),
                             (name: "BRD",           code: "BRD",   decimals: 18, symbol: "brd")]),
        ]

        static internal let addressBRDTestnet = "0x7108ca7c4718efa810457f228305c9c71390931a" // testnet
        static internal let addressBRDMainnet = "0x558ec3152e2eb2174905cd19aea4e34a23de9ad6" // mainnet

        /// Transfer

        public typealias Transfer = (
            id: String,
            source: String?,
            target: String?,
            amountValue: String,
            amountCurrency: String,
            acknowledgements: UInt64,
            index: UInt64,
            transactionId: String?,
            blockchainId: String)

        static internal func asTransfer (json: JSON) -> Model.Transfer? {
            guard let id = json.asString(name: "transfer_id"),
                let bid = json.asString(name: "blockchain_id"),
                let acknowledgements = json.asUInt64(name: "acknowledgements"),
                let index = json.asUInt64(name: "index"),
                let amount = json.asDict(name: "amount").map ({ JSON (dict: $0) }),
                let amountValue = amount.asString (name: "amount"),
                let amountCurrency = amount.asString (name: "currency_id")
                else { return nil }

            let source = json.asString(name: "from_address")
            let target = json.asString(name: "to_address")
            let tid = json.asString(name: "transaction_id")

            return (id: id, source: source, target: target,
                    amountValue: amountValue, amountCurrency: amountCurrency,
                    acknowledgements: acknowledgements, index: index,
                    transactionId: tid, blockchainId: bid)
        }

        /// Transaction

        public typealias Transaction = (
            id: String,
            blockchainId: String,
            hash: String,
            identifier: String,
            blockHash: String?,
            blockHeight: UInt64?,
            index: UInt64?,
            confirmations: UInt64?,
            status: String,
            size: UInt64,
            timestamp: Date?,
            firstSeen: Date,
            raw: Data?,
            transfers: [Transfer],
            acknowledgements: UInt64
        )

        static internal func asTransaction (json: JSON) -> Model.Transaction? {
            guard let id = json.asString(name: "transaction_id"),
                let bid        = json.asString (name: "blockchain_id"),
                let hash       = json.asString (name: "hash"),
                let identifier = json.asString (name: "identifier"),
                let status     = json.asString (name: "status"),
                let size       = json.asUInt64 (name: "size"),
                let firstSeen  = json.asDate   (name: "first_seen"),
                let acks       = json.asUInt64 (name: "acknowledgements")
                else { return nil }

            let blockHash     = json.asString (name: "block_hash")
            let blockHeight   = json.asUInt64 (name: "block_height")
            let index         = json.asUInt64 (name: "index")
            let confirmations = json.asUInt64 (name: "confirmations")
            let timestamp     = json.asDate   (name: "timestamp")

            let raw = json.asData (name: "raw")

            guard let transfers = json.asArray (name: "transfers")?
                .map ({ JSON (dict: $0 )})
                .map ({ asTransfer (json: $0)})
                else { return nil }

            return (id: id, blockchainId: bid,
                     hash: hash, identifier: identifier,
                     blockHash: blockHash, blockHeight: blockHeight, index: index, confirmations: confirmations, status: status,
                     size: size, timestamp: timestamp, firstSeen: firstSeen,
                     raw: raw,
                     transfers: (transfers as! [Transfer]),
                     acknowledgements: acks)
        }

        /// Block

        public typealias Block = (
            id: String,
            blockchainId: String,
            hash: String,
            height: UInt64,
            header: String?,
            raw: Data?,
            mined: Date,
            size: UInt64,
            prevHash: String?,
            nextHash: String?, // fees
            transactions: [Transaction]?,
            acknowledgements: UInt64
        )

        static internal func asBlock (json: JSON) -> Model.Block? {
            guard let id = json.asString(name: "block_id"),
                let bid      = json.asString(name: "blockchain_id"),
                let hash     = json.asString (name: "hash"),
                let height   = json.asUInt64 (name: "height"),
                let mined    = json.asDate   (name: "mined"),
                let size     = json.asUInt64 (name: "size"),
                let acks       = json.asUInt64 (name: "acknowledgements")
                else { return nil }

            let header   = json.asString (name: "header")
            let raw      = json.asData   (name: "raw")
            let prevHash = json.asString (name: "prev_hash")
            let nextHash = json.asString (name: "next_hash")

            let transactions = json.asArray (name: "transactions")?
                .map ({ JSON (dict: $0 )})
                .map ({ asTransaction (json: $0)}) as? [Model.Transaction]  // not quite

            return (id: id, blockchainId: bid,
                    hash: hash, height: height, header: header, raw: raw, mined: mined, size: size,
                    prevHash: prevHash, nextHash: nextHash,
                    transactions: transactions,
                    acknowledgements: acks)
        }

        /// Wallet

        public typealias WalletCurrency = (currency: String, addresses: [String])
        public typealias Wallet = (
            id: String,
            created: Date,
            currencies: [WalletCurrency]
        )

        static internal func asWalletCurrency (json: JSON) -> Model.WalletCurrency? {
            guard let currency = json.asString(name: "currency_id")
            else { return nil }

            let addresses = json.asStringArray(name: "addresses") ?? []

            return (currency: currency, addresses: addresses)
        }

        static internal func asJSON (walletCurrency: Model.WalletCurrency) -> JSON.Dict {
            return [
                "currency_id" : walletCurrency.currency,
                "addresses"   : walletCurrency.addresses
            ]
        }

        static internal func asWallet (json: JSON) -> Model.Wallet? {
            guard let id = json.asString (name: "wallet_id"),
                let created = json.asDate (name: "created")
                else { return nil }

            let currencies = json.asArray(name: "currencies")?
                .map { JSON (dict: $0) }
                .map { asWalletCurrency (json: $0) } as? [Model.WalletCurrency]
            ?? [] // not quite

            return (id: id, created: created, currencies: currencies)
        }

        /// Subscription

        public typealias SubscriptionEndpoint = (environment: String, kind: String, value: String)
        public typealias Subscription = (
            id: String,
            wallet: String,
            device: String,
            endpoint: SubscriptionEndpoint
        )

        static internal func asSubscriptionEndpoint (json: JSON) -> SubscriptionEndpoint? {
            guard let environment = json.asString (name: "environment"),
            let kind = json.asString(name: "kind"),
            let value = json.asString(name: "value")
                else { return nil }

            return (environment: environment, kind: kind, value: value)
        }

        static internal func asSubscription (json: JSON) -> Subscription? {
            guard let id = json.asString (name: "subscription_id"),
                let wallet = json.asString (name: "wallet_id"),
                let device = json.asString (name: "device_id"),
                let endpoint = json.asDict(name: "endpoint")
                    .flatMap ({ asSubscriptionEndpoint (json: JSON (dict: $0)) })
                else { return nil }

            return (id: id, wallet: wallet, device: device, endpoint: endpoint)
        }

    } // End of Model

    public func getBlockchains (mainnet: Bool? = nil, completion: @escaping (Result<[Model.Blockchain],QueryError>) -> Void) {
        bdbMakeRequest (path: "blockchains", query: mainnet.map { zip (["testnet"], [($0 ? "false" : "true")]) }) {
            (more: Bool, res: Result<[JSON], QueryError>) in
            precondition (!more)
            completion (res.flatMap {
                BlockChainDB.getManyExpected(data: $0, transform: Model.asBlockchain)
            })
        }
    }

    public func getBlockchain (blockchainId: String, completion: @escaping (Result<Model.Blockchain,QueryError>) -> Void) {
        bdbMakeRequest(path: "blockchains/\(blockchainId)", query: nil, embedded: false) {
            (more: Bool, res: Result<[JSON], QueryError>) in
            precondition (!more)
            completion (res.flatMap {
                BlockChainDB.getOneExpected (id: blockchainId, data: $0, transform: Model.asBlockchain)
            })
        }
    }

    public func getCurrencies (blockchainId: String? = nil, completion: @escaping (Result<[Model.Currency],QueryError>) -> Void) {
        bdbMakeRequest (path: "currencies", query: blockchainId.map { zip(["blockchain_id"], [$0]) }) {
            (more: Bool, res: Result<[JSON], QueryError>) in
            precondition (!more)
            completion (res.flatMap {
                BlockChainDB.getManyExpected(data: $0, transform: Model.asCurrency)
            })
        }
    }

    public func getCurrency (currencyId: String, completion: @escaping (Result<Model.Currency,QueryError>) -> Void) {
        bdbMakeRequest (path: "currencies/\(currencyId)", query: nil, embedded: false) {
            (more: Bool, res: Result<[JSON], QueryError>) in
            precondition (!more)
            completion (res.flatMap {
                BlockChainDB.getOneExpected(id: currencyId, data: $0, transform: Model.asCurrency)
            })
        }
    }

    public func getSubscription (id: String, completion: @escaping (Result<Model.Subscription, QueryError>) -> Void) {
        bdbMakeRequest (path: "subscriptions/\(id)", query: nil, embedded: false) {
            (more: Bool, res: Result<[JSON], QueryError>) in
            precondition (!more)
            completion (res.flatMap {
                BlockChainDB.getOneExpected (id: id, data: $0, transform: Model.asSubscription)
            })
        }
    }

    public func createSubscription (walletId: String, deviceId: String, endpointValue: String,
                                    completion: @escaping (Result<String, QueryError>) -> Void) {
        let json: JSON.Dict = [
            "wallet_id" : walletId,
            "device_id" : deviceId,
            "endpoint"  : [
                "environment" : "develop",          // not quite
                "type"        : "apns",
                "value"       : endpointValue
                ]
        ]

        makeRequest (bdbDataTaskFunc, bdbBaseURL,
                     path: "subscriptions",
                     query: nil,
                     data: json,
                     httpMethod: "POST") {
                        (res: Result<JSON.Dict, QueryError>) in
                        completion (res.flatMap {
                            JSON(dict: $0)
                                .asString (name: "subscription_id")
                                .map { Result.success($0) }
                            ?? Result.failure(QueryError.model("subscription"))
                        })
        }
    }

    public func getTransfers (blockchainId: String, addresses: [String], completion: @escaping (Result<[Model.Transfer], QueryError>) -> Void) {
        let queryKeys = ["blockchain_id"] + Array (repeating: "address", count: addresses.count)
        let queryVals = [blockchainId]    + addresses

        bdbMakeRequest (path: "transfers", query: zip (queryKeys, queryVals)) {
            (more: Bool, res: Result<[JSON], QueryError>) in
            completion (res.flatMap {
                BlockChainDB.getManyExpected (data: $0, transform: Model.asTransfer)
            })
        }
    }

    public func getTransfer (transferId: String, completion: @escaping (Result<Model.Transfer, QueryError>) -> Void) {
        bdbMakeRequest (path: "transfers/\(transferId)", query: nil, embedded: false) {
            (more: Bool, res: Result<[JSON], QueryError>) in
            precondition (!more)
            completion (res.flatMap {
                BlockChainDB.getOneExpected (id: transferId, data: $0, transform: Model.asTransfer)
            })
        }
    }

    public func getWallet (walletId: String, completion: @escaping (Result<Model.Wallet, QueryError>) -> Void) {
        bdbMakeRequest(path: "wallets/\(walletId)", query: nil, embedded: false) { (more: Bool, res: Result<[JSON], QueryError>) in
            precondition(!more)
            completion (res.flatMap {
                BlockChainDB.getOneExpected(id: walletId, data: $0, transform: Model.asWallet)
            })
        }
    }

    public func createWallet (id: String, currencies: [Model.WalletCurrency]) -> Void {
        let json: JSON.Dict = [
            "walletId"   : id,
            "currencies" : currencies.map { Model.asJSON(walletCurrency: $0) }
            ]

        makeRequest (bdbDataTaskFunc, bdbBaseURL,
                     path: "wallets",
                     query: nil,
                     data: json,
                     httpMethod: "POST") {
                        (res: Result<JSON.Dict, QueryError>) in
        }
    }

    // Transactions

    public func getTransactions (blockchainId: String,
                                 addresses: [String],
                                 begBlockNumber: UInt64 = 0,
                                 endBlockNumber: UInt64 = 0,
                                 includeRaw: Bool = false,
                                 includeProof: Bool = false,
                                 completion: @escaping (Result<[Model.Transaction], QueryError>) -> Void) {
        // This query could overrun the endpoint's page size (typically 5,000).  If so, we'll need
        // to repeat the request for the next batch.
        self.queue.async {
            let queryKeys = ["blockchain_id", "start_height", "end_height", "include_proof", "include_raw"]
                + Array (repeating: "address", count: addresses.count)

            var queryVals = [blockchainId, "0", "0", includeProof.description, includeRaw.description]
                + addresses

            let semaphore = DispatchSemaphore (value: 0)

//            var moreResults = false
            var begBlockNumber = begBlockNumber

            var error: QueryError? = nil
            var results = [Model.Transaction]()

            for begHeight in stride (from: begBlockNumber, to: endBlockNumber, by: 5000) {
                queryVals[1] = begHeight.description
                queryVals[2] = min (begHeight + 5000, endBlockNumber).description

                //                moreResults = false

                self.bdbMakeRequest (path: "transactions", query: zip (queryKeys, queryVals)) {
                    (more: Bool, res: Result<[JSON], QueryError>) in
                    // Flag if `more`
//                    moreResults = more

                    // Append `transactions` with the resulting transactions.
                    results += try! res
                        .flatMap { BlockChainDB.getManyExpected(data: $0, transform: Model.asTransaction) }
                        .recover { error = $0; return [] }.get()

                    if more && nil == error {
                        begBlockNumber = results.reduce(0) {
                            max ($0, ($1.blockHeight ?? 0))
                        }
                    }

                    semaphore.signal()
                }

                semaphore.wait()
                if nil != error { break }
            }

            completion (nil == error
                ? Result.success (results)
                : Result.failure (error!))
        }
    }

    public func getTransaction (transactionId: String,
                                includeRaw: Bool = false,
                                includeProof: Bool = false,
                                completion: @escaping (Result<Model.Transaction, QueryError>) -> Void) {
        let queryKeys = ["include_proof", "include_raw"]
        let queryVals = [includeProof.description, includeRaw.description]

        bdbMakeRequest (path: "transactions/\(transactionId)", query: zip (queryKeys, queryVals), embedded: false) {
            (more: Bool, res: Result<[JSON], QueryError>) in
            precondition (!more)
            completion (res.flatMap {
                BlockChainDB.getOneExpected (id: transactionId, data: $0, transform: Model.asTransaction)
            })
        }
    }

    public func putTransaction (blockchainId: String,
                                transaction: Data,
                                completion: @escaping (Result<Model.Transaction, QueryError>) -> Void) {
        let json: JSON.Dict = [
            "transaction" : transaction.base64EncodedData()
        ]

        makeRequest(bdbDataTaskFunc, bdbBaseURL,
                    path: "/transactions",
                    query: zip (["blockchain_id"], [blockchainId]),
                    data: json,
                    httpMethod: "PUT") {
                        (res: Result<JSON.Dict, BlockChainDB.QueryError>) in
                        completion (res.flatMap {
                            Model.asTransaction (json: JSON (dict: $0))
                                .map { Result.success($0) }
                                ?? Result.failure (QueryError.model ("(JSON) -> T transform error (one)"))
                        })
        }
    }

    // Blocks

    public func getBlocks (blockchainId: String,
                           begBlockNumber: UInt64 = 0,
                           endBlockNumber: UInt64 = 0,
                           includeRaw: Bool = false,
                           includeTx: Bool = false,
                           includeTxRaw: Bool = false,
                           includeTxProof: Bool = false,
                           completion: @escaping (Result<[Model.Block], QueryError>) -> Void) {
        self.queue.async {
            let semaphore = DispatchSemaphore (value: 0)

            var moreResults = false
            var begBlockNumber = begBlockNumber

            var error: QueryError? = nil
            var results = [Model.Block]()

            repeat {
                let queryKeys = ["blockchain_id", "start_height", "end_height",  "include_raw",
                                 "include_tx", "include_tx_raw", "include_tx_proof"]

                let queryVals = [blockchainId, begBlockNumber.description, endBlockNumber.description, includeRaw.description,
                                 includeTx.description, includeTxRaw.description, includeTxProof.description]

                self.bdbMakeRequest (path: "blocks", query: zip (queryKeys, queryVals)) {
                    (more: Bool, res: Result<[JSON], QueryError>) in

                    // Flag if `more`
                    moreResults = more

                    // Append `transactions` with the resulting transactions.  Be sure
                    results += try! res
                        .flatMap { BlockChainDB.getManyExpected(data: $0, transform: Model.asBlock) }
                        .recover { error = $0; return [] }.get()

                    if more && nil == error {
                        begBlockNumber = results.reduce(0) {
                            max ($0, $1.height)
                        }
                    }

                    semaphore.signal()
                }

                semaphore.wait()
            } while moreResults && nil == error

            completion (nil == error
                ? Result.success (results)
                : Result.failure (error!))
        }

    }

    public func getBlock (blockId: String,
                          includeRaw: Bool = false,
                          includeTx: Bool = false,
                          includeTxRaw: Bool = false,
                          includeTxProof: Bool = false,
                          completion: @escaping (Result<Model.Block, QueryError>) -> Void) {
        let queryKeys = ["include_raw", "include_tx", "include_tx_raw", "include_tx_proof"]

        let queryVals = [includeRaw.description, includeTx.description, includeTxRaw.description, includeTxProof.description]

        bdbMakeRequest (path: "blocks/\(blockId)", query: zip (queryKeys, queryVals), embedded: false) {
            (more: Bool, res: Result<[JSON], QueryError>) in
            precondition (!more)
            completion (res.flatMap {
                BlockChainDB.getOneExpected (id: blockId, data: $0, transform: Model.asBlock)
            })
        }
    }

    /// BTC
    public struct BTC {
        typealias Transaction = (btc: BRCoreTransaction, rid: Int32)
    }

    internal func getBlockNumberAsBTC (bwm: BRWalletManager,
                                       blockchainId: String,
                                       rid: Int32,
                                       done: @escaping (UInt64, Int32) -> Void) {
        getBlockchain (blockchainId: blockchainId) { (res: Result<Model.Blockchain, QueryError>) in
            switch res {
            case let .success (blockchain):
                done (blockchain.blockHeight, rid)
            case .failure(_):
                done (0, rid)  // No
            }
        }
    }

    internal func getTransactionsAsBTC (bwm: BRWalletManager,
                                        blockchainId: String,
                                        addresses: [String],
                                        begBlockNumber: UInt64,
                                        endBlockNumber: UInt64,
                                        rid: Int32,
                                        done: @escaping (Bool, Int32) -> Void,
                                        each: @escaping (BTC.Transaction) -> Void) {
        getTransactions (blockchainId: blockchainId,
                         addresses: addresses,
                         begBlockNumber: begBlockNumber,
                         endBlockNumber: endBlockNumber,
                         includeRaw: true) { (res: Result<[Model.Transaction], QueryError>) in
                            let btcRes = res
                                .flatMap { (dbTransactions: [Model.Transaction]) -> Result<[BRCoreTransaction], QueryError> in
                                    let transactions:[BRCoreTransaction?] = dbTransactions
                                        .map {
                                            guard let raw = $0.raw
                                                else { return nil }

                                            let bytes = [UInt8] (raw)
                                            guard let btcTransaction = BRTransactionParse (bytes, bytes.count)
                                                else { return nil }

                                            btcTransaction.pointee.timestamp =
                                                $0.timestamp.map { UInt32 ($0.timeIntervalSince1970) } ?? UInt32 (0)
                                            btcTransaction.pointee.blockHeight =
                                                $0.blockHeight.map { UInt32 ($0) } ?? 0

                                            return  btcTransaction
                                    }

                                    return transactions.contains(where: { nil == $0 })
                                        ? Result.failure (QueryError.model ("BRCoreTransaction parse error"))
                                        : Result.success (transactions as! [BRCoreTransaction])
                                }

                            switch btcRes {
                            case .failure: done (false, rid)
                            case let .success (btc):
                                btc.forEach { each ((btc: $0, rid: rid)) }
                                done (true, rid)
                            }
        }
    }

    /// ETH

    public struct ETH {
        public typealias Balance = (wid: BREthereumWallet, balance: String, rid: Int32)
        public typealias GasPrice = (wid: BREthereumWallet, gasPrice: String, rid: Int32)
        public typealias GasEstimate = (wid: BREthereumWallet, tid: BREthereumTransfer, gasEstimate: String, rid: Int32)

        public typealias Submit = (
            wid: BREthereumWallet,
            tid: BREthereumTransfer,
            hash: String,
            errorCode: Int32,
            errorMessage: String?,
            rid: Int32)

        public typealias Transaction = (
            hash: String,
            sourceAddr: String,
            targetAddr: String,
            contractAddr: String,
            amount: String,
            gasLimit: String,
            gasPrice: String,
            data: String,
            nonce: String,
            gasUsed: String,
            blockNumber: String,
            blockHash: String,
            blockConfirmations: String,
            blockTransactionIndex: String,
            blockTimestamp: String,
            isError: String,
            rid: Int32)

        static internal func asTransaction (json: JSON, rid: Int32) -> ETH.Transaction? {
            guard let hash = json.asString(name: "hash"),
                let sourceAddr   = json.asString(name: "from"),
                let targetAddr   = json.asString(name: "to"),
                let contractAddr = json.asString(name: "contractAddress"),
                let amount       = json.asString(name: "value"),
                let gasLimit     = json.asString(name: "gas"),
                let gasPrice     = json.asString(name: "gasPrice"),
                let data         = json.asString(name: "input"),
                let nonce        = json.asString(name: "nonce"),
                let gasUsed      = json.asString(name: "gasUsed"),
                let blockNumber  = json.asString(name: "blockNumber"),
                let blockHash    = json.asString(name: "blockHash"),
                let blockConfirmations    = json.asString(name: "confirmations"),
                let blockTransactionIndex = json.asString(name: "transactionIndex"),
                let blockTimestamp        = json.asString(name: "timeStamp"),
                let isError      = json.asString(name: "isError")
                else { return nil }

            return (hash: hash,
                    sourceAddr: sourceAddr, targetAddr: targetAddr, contractAddr: contractAddr,
                    amount: amount, gasLimit: gasLimit, gasPrice: gasPrice,
                    data: data, nonce: nonce, gasUsed: gasUsed,
                    blockNumber: blockNumber, blockHash: blockHash,
                    blockConfirmations: blockConfirmations, blockTransactionIndex: blockTransactionIndex, blockTimestamp: blockTimestamp,
                    isError: isError,
                    rid: rid)
        }

        public typealias Log = (
            hash: String,
            contract: String,
            topics: [String],
            data: String,
            gasPrice: String,
            gasUsed: String,
            logIndex: String,
            blockNumber: String,
            blockTransactionIndex: String,
            blockTimestamp: String,
            rid: Int32)

        // BRD API servcies *always* appends `topics` with ""; we need to axe that.
        static internal func dropLastIfEmpty (_ strings: [String]?) -> [String]? {
            return (nil != strings && !strings!.isEmpty && "" == strings!.last!
                ? strings!.dropLast()
                : strings)
        }

        static internal func asLog (json: JSON, rid: Int32) -> ETH.Log? {
            guard let hash = json.asString(name: "transactionHash"),
                let contract    = json.asString(name: "address"),
                let topics      = dropLastIfEmpty (json.asStringArray (name: "topics")),
                let data        = json.asString(name: "data"),
                let gasPrice    = json.asString(name: "gasPrice"),
                let gasUsed     = json.asString(name: "gasUsed"),
                let logIndex    = json.asString(name: "logIndex"),
                let blockNumber = json.asString(name: "blockNumber"),
                let blockTransactionIndex = json.asString(name: "transactionIndex"),
                let blockTimestamp        = json.asString(name: "timeStamp")
                else { return nil }

            return (hash: hash, contract: contract, topics: topics, data: data,
                    gasPrice: gasPrice, gasUsed: gasUsed,
                    logIndex: logIndex,
                    blockNumber: blockNumber, blockTransactionIndex: blockTransactionIndex, blockTimestamp: blockTimestamp,
                    rid: rid)
        }

        public typealias Token = (
            address: String,
            symbol: String,
            name: String,
            description: String,
            decimals: UInt32,
            defaultGasLimit: String?,
            defaultGasPrice: String?,
            rid: Int32)

        static internal func asToken (json: JSON, rid: Int32) -> ETH.Token? {
            guard let name   = json.asString(name: "name"),
                let symbol   = json.asString(name: "code"),
                let address  = json.asString(name: "contract_address"),
                let decimals = json.asUInt8(name: "scale")
                else { return nil }

            let description = "Token for '\(symbol)'"

            return (address: address, symbol: symbol, name: name, description: description,
                    decimals: UInt32(decimals),
                    defaultGasLimit: nil,
                    defaultGasPrice: nil,
                    rid: rid)
        }

        public typealias Block = (numbers: [UInt64], rid: Int32)
        public typealias BlockNumber = (number: String, rid: Int32)
        public typealias Nonce = (address: String, nonce: String, rid: Int32)
    }

    public func getBalanceAsETH (ewm: BREthereumEWM,
                                 wid: BREthereumWallet,
                                 address: String,
                                 rid: Int32,
                                 completion: @escaping (ETH.Balance) -> Void) {
        let json: JSON.Dict = [
            "jsonrpc" : "2.0",
            "method"  : "eth_getBalance",
            "params"  : [address, "latest"],
            "id"      : rid
        ]

        apiMakeRequestJSON(ewm: ewm, data: json) { (res: Result<JSON, QueryError>) in
            let balance = try! res
                .map { $0.asString (name: "result")! }
                .recover { (ignore) in "200000000000000000" }
                .get()

            completion ((wid: wid, balance: balance, rid: rid))
        }
    }

    public func getBalanceAsTOK (ewm: BREthereumEWM,
                                 wid: BREthereumWallet,
                                 address: String,
                                 rid: Int32,
                                 completion: @escaping (ETH.Balance) -> Void) {
        let json: JSON.Dict = [ "id" : rid ]

        let contract = asUTF8String(tokenGetAddress(ewmWalletGetToken(ewm, wid)))

        var queryDict = [
            "module"    : "account",
            "action"    : "tokenbalance",
            "address"   : address,
            "contractaddress" : contract
        ]

        apiMakeRequestQUERY (ewm: ewm,
                             query: zip (Array(queryDict.keys), Array(queryDict.values)),
                             data: json) { (res: Result<JSON, QueryError>) in
                                let balance = try! res
                                    .map { $0.asString (name: "result")! }
                                    .recover { (ignore) in "0x1" }
                                    .get()

                                completion ((wid: wid, balance: balance, rid: rid))
        }
    }

    public func getGasPriceAsETH (ewm: BREthereumEWM,
                                  wid: BREthereumWallet,
                                  rid: Int32,
                                  completion: @escaping (ETH.GasPrice) -> Void) {
        let json: JSON.Dict = [
            "method" : "eth_gasPrice",
            "params" : [],
            "id" : rid
        ]

        apiMakeRequestJSON(ewm: ewm, data: json) { (res: Result<JSON, QueryError>) in
            let gasPrice = try! res
                .map { $0.asString (name: "result")! }
                .recover { (ignore) in "0xffc0" }
                .get()

            completion ((wid: wid, gasPrice: gasPrice, rid: rid))
        }
    }

    public func getGasEstimateAsETH (ewm: BREthereumEWM,
                                     wid: BREthereumWallet,
                                     tid: BREthereumTransfer,
                                     from: String,
                                     to: String,
                                     amount: String,
                                     data: String,
                                     rid: Int32,
                                     completion: @escaping (ETH.GasEstimate) -> Void) {
        let json: JSON.Dict = [
            "jsonrpc" : "2.0",
            "method"  : "eth_getBalance",
            "params"  : [["from":from, "to":to, "value":amount, "data":data]],
            "id"      : rid
        ]

        apiMakeRequestJSON(ewm: ewm, data: json) { (res: Result<JSON, QueryError>) in
            let gasEstimate = try! res
                .map { $0.asString (name: "result")! }
                .recover { (ignore) in "92000" }
                .get()

            completion ((wid: wid, tid: tid, gasEstimate: gasEstimate, rid: rid))
        }
    }

    public func submitTransactionAsETH (ewm: BREthereumEWM,
                                        wid: BREthereumWallet,
                                        tid: BREthereumTransfer,
                                        transaction: String,
                                        rid: Int32,
                                        completion: @escaping (ETH.Submit) -> Void) {
        let json: JSON.Dict = [
            "jsonrpc" : "2.0",
            "method"  : "eth_sendRawTransaction",
            "params"  : [transaction],
            "id"      : rid
        ]

        apiMakeRequestJSON(ewm: ewm, data: json) { (res: Result<JSON, QueryError>) in
            let hash = try! res
                .map { $0.asString (name: "result")! }
                .recover { (ignore) in "0x123abc456def" }
                .get()

            completion ((wid: wid, tid: tid, hash: hash, errorCode: Int32(-1), errorMessage: nil, rid: rid))
        }
    }

    public func getTransactionsAsETH (ewm: BREthereumEWM,
                                      address: String,
                                      begBlockNumber: UInt64,
                                      endBlockNumber: UInt64,
                                      rid: Int32,
                                      done: @escaping (Bool, Int32) -> Void,
                                      each: @escaping (ETH.Transaction) -> Void) {
        let json: JSON.Dict = [
            "account" : address,
            "id"      : rid ]

        var queryDict = [
            "module"    : "account",
            "action"    : "txlist",
            "address"   : address,
            "startBlock": begBlockNumber.description,
            "endBlock"  : endBlockNumber.description
        ]

        apiMakeRequestQUERY (ewm: ewm, query: zip (Array(queryDict.keys), Array(queryDict.values)), data: json) {
            (res: Result<JSON, QueryError>) in

            let resLogs = res
                .flatMap({ (json: JSON) -> Result<[ETH.Transaction], QueryError> in
                    guard let _ = json.asString (name: "status"),
                        let   _ = json.asString (name: "message"),
                        let   result  = json.asArray (name:  "result")
                        else { return Result.failure(QueryError.model("Missed {status, message, result")) }

                    let transactions = result.map { ETH.asTransaction (json: JSON (dict: $0), rid: rid) }

                    return transactions.contains(where: { nil == $0 })
                        ? Result.failure (QueryError.model ("ETH.Transaction parse error"))
                        : Result.success (transactions as! [ETH.Transaction])
                })

            switch resLogs {
            case .failure: done (false, rid)
            case let .success(a):
                a.forEach { each ($0) }
                done (true, rid)
            }
        }
    }

    public func getLogsAsETH (ewm: BREthereumEWM,
                              contract: String?,
                              address: String,
                              event: String,
                              begBlockNumber: UInt64,
                              endBlockNumber: UInt64,
                              rid: Int32,
                              done: @escaping (Bool, Int32) -> Void,
                              each: @escaping (ETH.Log) -> Void) {
        let json: JSON.Dict = [ "id" : rid ]

        var queryDict = [
            "module"    : "logs",
            "action"    : "getLogs",
            "fromBlock" : begBlockNumber.description,
            "toBlock"   : endBlockNumber.description,
            "topic0"    : event,
            "topic1"    : address,
            "topic_1_2_opr" : "or",
            "topic2"    : address
        ]
        if nil != contract { queryDict["address"] = contract! }

        apiMakeRequestQUERY (ewm: ewm, query: zip (Array(queryDict.keys), Array(queryDict.values)), data: json) {
            (res: Result<JSON, QueryError>) in

            let resLogs = res
                .flatMap({ (json: JSON) -> Result<[ETH.Log], QueryError> in
                    guard let _ = json.asString (name: "status"),
                        let   _ = json.asString (name: "message"),
                        let   result  = json.asArray (name:  "result")
                        else { return Result.failure(QueryError.model("Missed {status, message, result")) }

                    let logs = result.map { ETH.asLog (json: JSON (dict: $0), rid: rid) }

                    return logs.contains(where: { nil == $0 })
                        ? Result.failure (QueryError.model ("ETH.Log parse error"))
                        : Result.success (logs as! [ETH.Log])
                })

            switch resLogs {
            case .failure: done (false, rid)
            case let .success(a):
                a.forEach { each ($0) }
                done (true, rid)
            }
        }
    }

    public func getTokensAsETH (ewm: BREthereumEWM,
                                rid: Int32,
                                done: @escaping (Bool, Int32) -> Void,
                                each: @escaping (ETH.Token) -> Void) {
        // Everything returned by BRD must/absolutely-must be in BlockChainDB currencies.  Thus,
        // when stubbed, so too must these.
        apiMakeRequestTOKEN (ewm: ewm) { (res: Result<[JSON.Dict], QueryError>) in
            let resTokens = res
                .flatMap({ (jsonArray: [JSON.Dict]) -> Result<[ETH.Token], QueryError> in
                    let tokens = jsonArray.map { ETH.asToken (json: JSON (dict: $0), rid: rid) }

                    return tokens.contains(where: { nil == $0 })
                        ? Result.failure (QueryError.model ("ETH.Tokens parse error"))
                        : Result.success (tokens as! [ETH.Token])

                })

            switch resTokens {
            case .failure: done (false, rid)
            case let .success(a):
                a.forEach { each ($0) }
                done (true, rid)
            }
        }
    }

    public func getBlocksAsETH (ewm: BREthereumEWM,
                                address: String,
                                interests: UInt32,
                                blockStart: UInt64,
                                blockStop: UInt64,
                                rid: Int32,
                                completion: @escaping (ETH.Block) -> Void) {
        func parseBlockNumber (_ s: String) -> UInt64? {
            return s.starts(with: "0x")
                ? UInt64 (s.dropFirst(2), radix: 16)
                : UInt64 (s)
        }

        queue.async {
            let semaphore = DispatchSemaphore (value: 0)

            var transactions: [ETH.Transaction] = []
            var transactionsSuccess: Bool = false

            var logs: [ETH.Log] = []
            var logsSuccess: Bool = false

            self.getTransactionsAsETH (ewm: ewm,
                                       address: address,
                                       begBlockNumber: blockStart,
                                       endBlockNumber: blockStop,
                                       rid: rid,
                                       done: { (success:Bool, rid:Int32) in
                                        transactionsSuccess = success
                                        semaphore.signal() },
                                       each: { transactions.append ($0) })

            self.getLogsAsETH (ewm: ewm,
                               contract: nil,
                               address: address,
                               event: "0xa9059cbb",  // ERC20 Transfer
                               begBlockNumber: blockStart,
                               endBlockNumber: blockStop,
                               rid: rid,
                               done: { (success:Bool, rid:Int32) in
                                logsSuccess = success
                                semaphore.signal() },
                               each: { logs.append ($0) })

            semaphore.wait()
            semaphore.wait()

            var numbers: [UInt64] = []
            if transactionsSuccess && logsSuccess {
                numbers += transactions
                    .filter {
                        return (
                            /* CLIENT_GET_BLOCKS_TRANSACTIONS_AS_TARGET */
                            (0 != (interests & UInt32 (1 << 0)) && address == $0.sourceAddr) ||

                                /* CLIENT_GET_BLOCKS_TRANSACTIONS_AS_TARGET */
                                (0 != (interests & UInt32 (1 << 1)) && address == $0.targetAddr))
                    }
                    .map { parseBlockNumber ($0.blockNumber) ?? 0 }

                numbers += logs
                    .filter {
                        if $0.topics.count != 3 { return false }
                        return (
                            /* CLIENT_GET_BLOCKS_LOGS_AS_SOURCE */
                            (0 != (interests & UInt32 (1 << 2)) && address == $0.topics[1]) ||
                                /* CLIENT_GET_BLOCKS_LOGS_AS_TARGET */
                                (0 != (interests & UInt32 (1 << 3)) && address == $0.topics[2]))
                    }
                    .map { parseBlockNumber($0.blockNumber) ?? 0}
            }

            completion ((numbers: numbers, rid: rid))
        }
    }

    public func getBlockNumberAsETH (ewm: BREthereumEWM,
                                     rid: Int32,
                                     completion: @escaping (ETH.BlockNumber) -> Void) {
        let json: JSON.Dict = [
            "method" : "eth_blockNumber",
            "params" : [],
            "id" : rid
        ]

        apiMakeRequestJSON(ewm: ewm, data: json) { (res: Result<JSON, QueryError>) in
            let result = try! res
                .map { $0.asString (name: "result")! }
                .recover { (ignore) in "0xffc0" }
                .get()

            completion ((number: result, rid: rid ))
        }
    }
    
    public func getNonceAsETH (ewm: BREthereumEWM,
                               address: String,
                               rid: Int32,
                               completion: @escaping (ETH.Nonce) -> Void) {
        let json: JSON.Dict = [
            "method" : "eth_getTransactionCount",
            "params" : [address, "latest"],
            "id" : rid
        ]

        apiMakeRequestJSON(ewm: ewm, data: json) { (res: Result<JSON, QueryError>) in
            let result = try! res
                .map { $0.asString (name: "result")! }
                .recover { (ignore) in "118" }
                .get()
            completion ((address: address, nonce: result, rid: rid ))
        }
    }

     static internal let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()

    internal struct JSON {
        typealias Dict = [String:Any]

        let dict: Dict

        init (dict: Dict) {
            self.dict = dict
        }

        internal func asString (name: String) -> String? {
            return dict[name] as? String
        }

        internal func asBool (name: String) -> Bool? {
            return dict[name] as? Bool
        }

        internal func asUInt64 (name: String) -> UInt64? {
            return (dict[name] as? NSNumber)
                .flatMap { UInt64 (exactly: $0)}
        }

        internal func asUInt8 (name: String) -> UInt8? {
            return (dict[name] as? NSNumber)
                .flatMap { UInt8 (exactly: $0)}
        }

        internal func asDate (name: String) -> Date? {
            return (dict[name] as? String)
                .flatMap { dateFormatter.date (from: $0) }
        }

        internal func asData (name: String) -> Data? {
            return (dict[name] as? String)
                .flatMap { Data (base64Encoded: $0)! }
        }

        internal func asArray (name: String) -> [Dict]? {
            return dict[name] as? [Dict]
        }

        internal func asDict (name: String) -> Dict? {
            return dict[name] as? Dict
        }

        internal func asStringArray (name: String) -> [String]? {
            return dict[name] as? [String]
        }
    }

    private func sendRequest<T> (_ request: URLRequest, _ dataTaskFunc: DataTaskFunc, completion: @escaping (Result<T, QueryError>) -> Void) {
        dataTaskFunc (session, request) { (data, res, error) in
            guard nil == error else {
                completion (Result.failure(QueryError.submission (error!))) // NSURLErrorDomain
                return
            }

            guard let res = res as? HTTPURLResponse else {
                completion (Result.failure (QueryError.url ("No Response")))
                return
            }

            guard 200 == res.statusCode else {
                completion (Result.failure (QueryError.url ("Status: \(res.statusCode) ")))
                return
            }

            guard let data = data else {
                completion (Result.failure (QueryError.noData))
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? T
                    else {
                        print ("SYS: API: ERROR: JSON.Dict: \(data.map { String(format: "%c", $0) }.joined())")
                        completion (Result.failure(QueryError.jsonParse(nil)));
                        return }

                completion (Result.success (json))
            }
            catch let jsonError as NSError {
                print ("SYS: API: ERROR: JSON.Error: \(data.map { String(format: "%c", $0) }.joined())")
                completion (Result.failure (QueryError.jsonParse (jsonError)))
                return
            }
            }.resume()
    }

    internal func makeRequest<T> (_ dataTaskFunc: DataTaskFunc,
                                  _ baseURL: String,
                                  path: String,
                                  query: Zip2Sequence<[String],[String]>? = nil,
                                  data: JSON.Dict? = nil,
                                  httpMethod: String = "POST",
                                  completion: @escaping (Result<T, QueryError>) -> Void) {
        guard var urlBuilder = URLComponents (string: baseURL)
            else { completion (Result.failure(QueryError.url("URLComponents"))); return }

        urlBuilder.path = path.starts(with: "/") ? path : "/\(path)"
        if let query = query {
            urlBuilder.queryItems = query.map { URLQueryItem (name: $0, value: $1) }
        }

        guard let url = urlBuilder.url
            else { completion (Result.failure (QueryError.url("URLComponents.url"))); return }

        print ("SYS: Request: \(url.absoluteString): Data: \(data?.description ?? "[]")")

        var request = URLRequest (url: url)
        request.addValue ("application/json", forHTTPHeaderField: "accept")
        request.addValue ("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = httpMethod

        // If we have data as a JSON.Dict, then add it as the httpBody to the request.
        if let data = data {
            do { request.httpBody = try JSONSerialization.data (withJSONObject: data, options: []) }
            catch let jsonError as NSError {
                completion (Result.failure (QueryError.jsonParse(jsonError)))
            }
        }

        sendRequest (request, dataTaskFunc, completion: completion)
    }

    internal func bdbMakeRequest (path: String,
                                  query: Zip2Sequence<[String],[String]>?,
                                  embedded: Bool = true,
                                  completion: @escaping (Bool, Result<[JSON], QueryError>) -> Void) {
        makeRequest (bdbDataTaskFunc, bdbBaseURL,
                     path: path,
                     query: query,
                     data: nil,
                     httpMethod: "GET") { (res: Result<JSON.Dict, QueryError>) in
                        let res = res.map { JSON (dict: $0) }

                        // See if there is a 'page' Dict in the JSON
                        let page: JSON.Dict? = try! res
                            .map { $0.asDict(name: "page") }
                            .recover { (ignore) in return nil }
                            .get()

                        // The page is full if 'total_pages' is more than 1
                        let full: Bool = page.map { (($0["total_pages"] as? Int) ?? 0) > 1 } ?? false

                        // If called not embedded then never be full
                        // precondition (...)

                        // Callback with `more` and the result (maybe error)
                        completion (false && (embedded && full),
                            res.flatMap { (json: JSON) -> Result<[JSON], QueryError> in
                                let json = (embedded
                                    ? json.asDict(name: "_embedded")?[path]
                                    : [json.dict])

                                guard let data = json as? [JSON.Dict]
                                    else { return Result.failure(QueryError.model ("[JSON.Dict] expected")) }

                                return Result.success (data.map { JSON (dict: $0) })
                        })
        }
    }

    internal func apiMakeRequestJSON (ewm: BREthereumEWM, data: JSON.Dict, completion: @escaping (Result<JSON, QueryError>) -> Void) {
        let path = "/ethq/\(BlockChainDB.networkNameFrom(ewm:ewm).lowercased())/proxy"
        makeRequest (apiDataTaskFunc, apiBaseURL,
                     path: path,
                     query: nil,
                     data: data,
                     httpMethod: "POST") { (res: Result<JSON.Dict, QueryError>) in
                        completion (res.map { JSON (dict: $0) })
        }
    }

    internal func apiMakeRequestQUERY (ewm: BREthereumEWM,
                                       query: Zip2Sequence<[String],[String]>?,
                                       data: JSON.Dict,
                                       completion: @escaping (Result<JSON, QueryError>) -> Void) {
        let path = "/ethq/\(BlockChainDB.networkNameFrom(ewm:ewm).lowercased())/query"
        makeRequest (apiDataTaskFunc, apiBaseURL,
                     path: path,
                     query: query,
                     data: data,
                     httpMethod: "POST") { (res: Result<JSON.Dict, QueryError>) in
                        completion (res.map { JSON (dict: $0) })
        }
    }

    internal func apiMakeRequestTOKEN (ewm: BREthereumEWM,
                                       completion: @escaping (Result<[JSON.Dict], QueryError>) -> Void) {
        let path = "/currencies"
        makeRequest (apiDataTaskFunc, apiBaseURL,
                     path: path,
                     query: zip(["type"], ["erc20"]),
                     data: nil,
                     httpMethod: "GET",
                     completion: completion)
    }

    ///
    /// Convert an array of JSON into a single value using a specified transform
    ///
    /// - Parameters:
    ///   - id: If not value exists, report QueryError.NoEntity (id: id)
    ///   - data: The array of JSON
    ///   - transform: Function to tranfrom JSON -> T?
    ///
    /// - Returns: A `Result` with success of `T`
    ///
    private static func getOneExpected<T> (id: String, data: [JSON], transform: (JSON) -> T?) -> Result<T, QueryError> {
        switch data.count {
        case  0:
            return Result.failure (QueryError.noEntity(id: id))
        case  1:
            guard let transfer = transform (data[0])
                else { return Result.failure (QueryError.model ("(JSON) -> T transform error (one)"))}
            return Result.success (transfer)
        default:
            return Result.failure (QueryError.model ("(JSON) -> T expected one only"))
        }
    }

    ///
    /// Convert an array of JSON into an array of `T` using a specified transform.  If any
    /// individual JSON cannot be converted, then a QueryError is return for `Result`
    ///
    /// - Parameters:
    ///   - data: Array of JSON
    ///   - transform: Function to transform JSON -> T?
    ///
    /// - Returns: A `Result` with success of `[T]`
    ///
    private static func getManyExpected<T> (data: [JSON], transform: (JSON) -> T?) -> Result<[T], QueryError> {
        let results = data.map (transform)
        return results.contains(where: { $0 == nil })
            ? Result.failure(QueryError.model ("(JSON) -> T transform error (many)"))
            : Result.success(results as! [T])
    }

    ///
    /// Derive the network name from `ewm`.
    ///
    /// - Parameter ewm:
    /// - Returns:
    ///
    private static func networkNameFrom (ewm: BREthereumEWM) -> String {
        return asUTF8String (networkGetName (ewmGetNetwork (ewm)))
    }
}