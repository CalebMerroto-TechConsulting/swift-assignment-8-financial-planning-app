import UIKit

// MARK: - Enums
enum ERROR: Error {
    case transactionError(_ message: String)
    case insufficientFunds(_ message: String)
    case systemError(_ message: String)
    case accessDenied(_ message: String)
    case paymentError(_ message: String)
    
    func print() -> String {
        switch self {
        case .transactionError(let message):
            return "TRANSACTION ERROR: \(message)"
        case .insufficientFunds(let message):
            return "ACCOUNT ERROR: \(message)"
        case .systemError(let message):
            return "SYSTEM ERROR: \(message)"
        case .accessDenied(let message):
            return "ACCESS ERROR: \(message)"
        case .paymentError(let message):
            return "PAYMENT ERROR: \(message)"
        }
    }
}

enum Transaction{
    case deposit(_ client: String, _ amt: Double,_ account: String, finalBalance: Double? = nil, accessKey: AccessKey? = nil)
    case withdraw(_ client: String, _ amt: Double,_ account: String, finalBalance: Double? = nil, accessKey: AccessKey? = nil)
    case purchase(_ client: String, _ amt: Double,_ accessKey: AccessKey,_ from: String,_ fromType: String,_ to: String,_ toClient: String)
    case interest(_ type: String, _ client: String,_ account: String,_ amt: Double? = nil)
    case bill(_ client: String, _ amt: Double,_ accessKey: AccessKey,_ payerAcc: String,_ payerType: String,_ payer: String,_ receiver: String,_ reason: String)
    case createAccount(_ account: String, type: String, owner: String, initialBalance: Double)
    case addToAccount(_ account: String,_ type: String,_ client: String,_ permissions: KeyPerms)
    case initAccount(_ account: String, type: String, owner: String, permissions: KeyPerms)
    case transfer(_ amt: Double,_ client: String,_ from: String,_ fromType: String,_ to: String,_ toType: String)
    case failed(_ message: ERROR)
    case partial(_ client: String,_ amt: Double,_ remainder: Double,_ account: String,_ type: String, finalBalance: Double? = nil)
    case requestBalance(_ client: String,_ account: String,_ type: String,_ balance: Double,_ accessKey: AccessKey)
    case spacer
    case section(_ header: String)
    
    func print(_ bank: Bank) -> String{
        switch self {
        case .deposit(let client, let amt, let account, let finalBalance, _):
            var msg = "Value of $\(amt) deposited into account: \(account) by \(client)."
            if let balance = finalBalance{
                msg.append(" - New balance: \(balance)")
            }
        case .withdraw(let client, let amt, let account, let finalBalance, _):
            var msg = "Value of $\(amt) withdrawn from account: \(account) by \(client)."
            if let balance = finalBalance{
                msg.append(" - New balance: \(balance)")
            }
        case .purchase(let client, let amt, _, let from, let fromType, let to, let toClient):
            return "\(client) made a purchase of $\(amt) from \(toClient) using \(fromType) account: \(from)"
        case .interest(let type,let client, let account, let amt):
            return "Interest accrued on \(type) account: \(account) owned by \(client) at value of $\(amt ?? 0)"
        case .bill(let client, let amt, _, let payerAcc, let payerType, let payer, let receiver, let reason):
            return "Bill of $\(amt) paid to \(receiver) by \(payer) for \(reason) using \(payerType) account: \(payerAcc)"
        case .createAccount(let account, let type, let owner, let initialBalance):
            "Account \(account) of type \(type) created for \(owner) with initial balance of $\(initialBalance)"
        case .addToAccount(let account, let type, let client, let permissions):
            switch permissions {
            case .full, .admin:
                return "\(client) added to \(type) account: \(account) as joint-owner"
            case .deposit:
                return "\(client) added to \(type) account: \(account) as deposit-only"
            case .withdraw:
                return "\(client) added to \(type) account: \(account) as withdraw-only"
            case .view:
                return "\(client) added to \(type) account: \(account) as view-only"
            }
        case .initAccount(let account, let type, let client, let permissions):
            switch permissions {
            case .full, .admin:
                return "\(client) added to \(type) account: \(account) as primary-owner"
            case .deposit:
                return "\(client) added to \(type) account: \(account) as deposit-only"
            case .withdraw:
                return "\(client) added to \(type) account: \(account) as withdraw-only"
            case .view:
                return "\(client) added to \(type) account: \(account) as view-only"
            }
        case .transfer(let amt, let client, let from, let fromType, let to, let toType):
            return "\(client) transferred $\(amt) from \(fromType) account: \(from) to \(toType) account: \(to)"
        case .partial(let client, let amt, let remainder, let account, let type, let finalBalance):
            var msg = "\(client) attempted to withdraw $\(amt + remainder) from \(type) account: \(account), but only hit withdraw limit. \n - $\(amt) of $\(amt + remainder) withdrawn."
            if let balance = finalBalance{
                msg.append(" - New balance: $\(balance)")
            }
            return msg
        case .failed(let message):
            return message.print()
        case .requestBalance(let client, let account, let type, let balance, _):
            return "\(client) requested balance for \(type) account: \(account) - Current balance: $\(balance)"
        case .spacer:
            return " "
        case .section(let header):
            return "\n##################################################\n\(header)\n##################################################\n"
        }
        return "invalid transaction"
    }
}

enum KeyPerms: Equatable {
    case deposit
    case withdraw
    case full
    case admin
    case view
    
     
}

// MARK: - Helper Structs

struct AccessKey: Equatable {
    let key: String
    let perms: KeyPerms
    
    init(_ key: String,_ perms: KeyPerms = .full){
        self.key = key
        self.perms = perms
    }
}

// MARK: - Protocols

protocol Flaggable {
    var flags: [String:Double?] { get }
    func hasFlag(_ flag: String) -> Bool
}

protocol Account: AnyObject, Flaggable {
    var owners: [String] { get set }
    var type: String { get }
    var accessKeys: [String:AccessKey] { get set}
    var balance: Double { get set }
    var accountNumber: String { get }
    var interestRate: Double { get set }
    var badKey: ERROR { get }
    var noKey: ERROR { get }
    
    
    func transact(_ transaction: Transaction) -> Transaction
    func verify (_ givenKey: String?, _ acc: String,_ requestedPerm: KeyPerms) -> Bool
    func interestCalc() -> Transaction
    
}

// MARK: - Extensions

extension Flaggable {
    func hasFlag(_ flag: String) -> Bool {
        return flags[flag] != nil
    }
}

extension Account {
    func verify(_ givenKey: String?, _ acc: String,_ requestedPerm: KeyPerms) -> Bool{
        if acc != accountNumber { return false }
        if let key = givenKey {
            if let perm = accessKeys[key]?.perms {
                return perm == requestedPerm
            }
        }
        return false
    }
    func transact(_ transaction: Transaction) -> Transaction {
        switch transaction {
        case .deposit(let client, let amt, let acc, _, let givenKey):
            if verify(givenKey?.key, acc, .deposit) {
                balance += amt
                return Transaction.deposit(client,amt, acc, finalBalance: balance)
            } else {
                return Transaction.failed(badKey)
            }
        case .withdraw(let client, let amt, let acc, _, let givenKey):
            if verify(givenKey?.key, acc, .withdraw) {
                var withdrawAmt = amt

                // Force unwrap if necessary, but log an error if it's unexpectedly nil
                if let lim = flags["withdraw limit"] {
                    if let maxWithdraw = lim {
                        if amt > maxWithdraw {
                            withdrawAmt = maxWithdraw // Apply the withdrawal limit
                        }
                    } else {
                        return .failed(.systemError("Account \(accountNumber) is flagged for a withdrawal limit, but no limit was provided."))
                    }
                }

                // Now check if we have enough balance for the allowed amount
                if balance >= withdrawAmt {
                    balance -= withdrawAmt

                    if withdrawAmt < amt {
                        return .partial(client, withdrawAmt, amt - withdrawAmt, acc, type, finalBalance: balance)
                    } else {
                        return .withdraw(client, amt, acc, finalBalance: balance, accessKey: givenKey)
                    }
                } else {
                    return .failed(.insufficientFunds("Insufficient balance in account \(acc). Available: \(balance), Required: \(withdrawAmt)"))
                }
            } else {
                return .failed(badKey)
            }
        case .interest:
            return interestCalc()
        case .purchase(let client, let price, let givenKey, let from, let fromType, let to, let toClient):
            guard hasFlag("can purchase") else {
                return .failed(ERROR.paymentError("Cannot make purchases with this account"))
            }
            if verify(givenKey.key, from, .withdraw) {
                    if let lim = flags["withdraw limit"], let maxWithdraw = lim {
                        if price > maxWithdraw {
                            return .failed(.insufficientFunds("Cannot make a purchase for more than \(maxWithdraw)"))
                        }
                    }
                    
                    if balance < price {
                        return .failed(.insufficientFunds("Insufficient balance in account \(from). Available: \(balance), Required: \(price)"))
                    }
                    
                    balance -= price
                    return Transaction.purchase(client, price, givenKey, from, fromType, to, toClient)
                }
            else if verify(givenKey.key, to, .deposit){
                balance += price
                return Transaction.purchase(client, price, givenKey, from, fromType, to, toClient)
            }
            else {
                return Transaction.failed(badKey)
            }
        case .bill(let client, let amt, let givenKey, let payerAcc, let payerType, let payer, let receiver, let reason):
            if hasFlag("billable") {
                if verify(givenKey.key, payer, .withdraw) {
                    balance -= amt
                    return Transaction.bill(client, amt, givenKey, payerAcc, payerType, payer, receiver, reason)
                } else {
                    return Transaction.failed(badKey)
                }
            }
            else {
                return Transaction.failed(ERROR.paymentError("Cannot pay bills with this account"))
            }
        default:
            break
        }
        return Transaction.failed(ERROR.systemError("Invalid Transaction"))
    }
    func interestCalc() -> Transaction{
        var interest: Double = balance * interestRate
        balance += interest
        return Transaction.interest(type, owners[0], accountNumber, interest)
    }
}

// MARK: - Operators

func ==(lhs: any Account, rhs: any Account) -> Bool {
    return lhs.accountNumber == rhs.accountNumber
}
func ==(lhs: any Account, rhs: String) -> Bool {
    return lhs.accountNumber == rhs
}
func ==(lhs: String, rhs: any Account) -> Bool {
    return lhs == rhs.accountNumber
}

func == (_ lhs: AccessKey, _ rhs: AccessKey) -> Bool {
    lhs.key == rhs.key
}

func == (lhs: KeyPerms, rhs: KeyPerms) -> Bool {
    switch (lhs, rhs) {
    case (.full, _), (_, .full), (.admin, _), (_, .admin): // full or admin permissions always return true
        return true
    case (.deposit, .deposit), (.withdraw, .withdraw), (.view, .view):
        return true
    default:
        return false
    }
}

// MARK: - Account Types

class SavingsAccount: Account {
    var owners: [String] = []
    var type = "Savings"
    var accessKeys: [String:AccessKey] = [:]
    var accountNumber: String
    var interestRate: Double
    var balance: Double = 0
    let badKey = ERROR.accessDenied("Invalid Access Key")
    let noKey = ERROR.accessDenied("Access Key Required")
    var flags: [String : Double?] = [:]

    init(_ accountNumber: String,_ accessKey: AccessKey,_ interestRate: Double,_ witthdrawLimit: Double) {
        self.accountNumber = accountNumber
        self.interestRate = interestRate
        accessKeys[accessKey.key] = accessKey
        flags["withdraw limit"] = witthdrawLimit
        
    }
}
class CheckingAccount: Account{
    
    var owners: [String] = []
    var type = "Checking"
    var accessKeys: [String:AccessKey] = [:]
    var accountNumber: String
    var interestRate: Double
    var balance: Double = 0
    let badKey = ERROR.accessDenied("Invalid Access Key")
    let noKey = ERROR.accessDenied("Access Key Required")
    var flags: [String : Double?] = ["can purchase":nil, "billable":nil]
    
    init(_ accountNumber: String,_ accessKey: AccessKey,_ interestRate: Double,_ witthdrawLimit: Double?,_ overDraftFee: Double?) {
        self.accountNumber = accountNumber
        self.interestRate = interestRate
        accessKeys[accessKey.key] = accessKey
        if let wl = witthdrawLimit {
            flags["withdraw limit"] = witthdrawLimit
        }
        if let of = overDraftFee {
            flags["overdraft fee"] = overDraftFee
        }
        
    }
}
class BillingAccount: Account{
    var owners: [String] = []
    var type = "Billing"
    var accessKeys: [String:AccessKey] = [:]
    var accountNumber: String
    var interestRate: Double
    var balance: Double = 0
    let badKey = ERROR.accessDenied("Invalid Access Key")
    let noKey = ERROR.accessDenied("Access Key Required")
    var flags: [String : Double?] = ["billable":nil]
    
    init(_ accountNumber: String,_ accessKey: AccessKey,_ interestRate: Double) {
        self.accountNumber = accountNumber
        self.interestRate = interestRate
        accessKeys[accessKey.key] = accessKey
    }
}

// MARK: - Main Classes

class Stack<T> {
    var items: [T]
    var count: Int { return items.count }
    
    
    init(_ items: [T] = []) {
        self.items = items
    }
    
    func push(_ item: T) {
        items.append(item)
    }
    func pop() -> T? {
        return items.popLast()
    }
    
    subscript(index: Int) -> T {
        return items[index]
    }
}

class Client {
    unowned var bank: Bank!
    var name: String
    let clientKey: AccessKey
    
    var accounts: [String: (any Account)] = [:]
    var accountKeys: [String:AccessKey] = [:]

    let addPermErr = ERROR.systemError("admin permissions required to add client to account")
    
    
    init(_ name: String,_ bank: Bank) {
        self.name = name
        self.bank = bank
        clientKey = AccessKey(name, .view)
    }
    
    private func generateKey(for account: any Account) -> String {
            var newKey: String
            repeat {
                newKey = String(format: "%06d", Int.random(in: 0...999999))
            } while isKeyUsed(newKey, account: account)
            
            return newKey
        }
    private func isKeyUsed(_ key: String, account: any Account) -> Bool {
        if account.accessKeys[key] != nil {
            return true
        }
        
        return accountKeys.values.contains { $0.key == key }
    }
    
    private func checkAuth(_ auth: AccessKey) throws -> Bool{
        if auth.perms != .admin {
            throw addPermErr
        }
        return true
    }
    
    func PreTransactionChecks(_ acc: String) throws -> (AccessKey, (any Account)) {
        let noKey = ERROR.accessDenied("No Key found for account \(acc).")
        let noAccount = ERROR.systemError("Account \(acc) not found.")
        
        
        guard let key = accountKeys[acc] else {
            throw noKey
        }
        
        guard let account = accounts[acc] else {
            throw noAccount
        }
        
        return (key, account)
    }
    
    func initAccount(_ account: (any Account),_ auth: AccessKey,_ ownerKey: AccessKey) {
        do {
            try checkAuth(auth)
            account.accessKeys[ownerKey.key] = ownerKey
            account.owners.append(name)
            accounts[account.accountNumber] = account
            accountKeys[account.accountNumber] = ownerKey
            let transact = Transaction.initAccount(account.accountNumber, type: account.type, owner: name, permissions: ownerKey.perms)
            bank.logTransaction(transact)
        }
        catch {
            bank.logTransaction(Transaction.failed(error as! ERROR))
        }
    }
    func addAccount(_ acc: String,_ auth: AccessKey ,_ perms: KeyPerms) {
        if let account = bank?.getAccount(acc) {
            addAccount(account, auth, AccessKey(generateKey(for: account), perms))
//            addAccount(account, auth, AccessKey("NewKey", perms))
        }
        else {
            bank.logTransaction(Transaction.failed(ERROR.systemError("Add Account Failed: Account not found")))
        }
    }
    func addAccount(_ account: (any Account),_ auth: AccessKey,_ key: AccessKey){
        do {
            try checkAuth(auth)
            account.accessKeys[key.key] = key
            account.owners.append(name)
            accounts[account.accountNumber] = account
            accountKeys[account.accountNumber] = key
            let transact = Transaction.addToAccount(account.accountNumber,account.type, name, key.perms)
            bank.logTransaction(transact)
        }
        catch {
            bank.logTransaction(Transaction.failed(error as! ERROR))
        }
    }
    
    
    func spend(_ amount: Double, _ acc: String, _ sellerAccount: String) {
        do{
            let accessDenied = ERROR.accessDenied("Invalid permissions for making purchases.")
            var accessKey: AccessKey
            var account: (any Account)
            var result: Transaction
            
            (accessKey, account) = try PreTransactionChecks(acc)
            
            if accessKey.perms != .withdraw {
                throw accessDenied
            }
            
            guard let seller = bank.getAccount(sellerAccount) else {
                throw ERROR.systemError("Account \(sellerAccount) not found.")
            }
            
            let purchase = Transaction.purchase(name, amount, accessKey, acc, account.type, sellerAccount, seller.owners[0])
            result = account.transact(purchase)
            switch result {
            case .purchase:
                result = seller.transact(purchase)
            case .failed(let error):
                result = Transaction.failed(error)
            default:
                result = Transaction.failed(.systemError("Purchase Failed: Unknown Error"))
            }
            
            
            bank.logTransaction(result)
        }
        catch {
            bank.logTransaction(Transaction.failed(error as! ERROR))
            return
        }
    }
    func bill(_ amount: Double, _ acc: String, _ sellerAccount: String,_ reason: String) {
        do{
            let accessDenied = ERROR.accessDenied("Invalid permissions for making purchases.")
            var accessKey: AccessKey
            var account: (any Account)
            
            
            (accessKey, account) = try PreTransactionChecks(acc)
            
            if accessKey.perms != .withdraw {
                throw accessDenied
            }
            
            guard let receiver = bank.getAccount(sellerAccount) else {
                throw ERROR.systemError("Account \(sellerAccount) not found.")
            }
            
            let transaction = Transaction.bill(name, amount, accessKey, acc, account.type, name, receiver.owners[0], reason)
            let result = account.transact(transaction)
            receiver.transact(transaction)
            
            
            bank.logTransaction(result)
        }
        catch {
            bank.logTransaction(Transaction.failed(error as! ERROR))
            return
        }
    }
    func transfer(_ amount: Double, _ from: String, _ to: String) {
        do{
            let accessDenied = ERROR.accessDenied("Invalid permissions to transfer from account: \(from) to account: \(to).")
            var fromKey: AccessKey
            var toKey: AccessKey
            var fromAcc: (any Account)
            var toAcc: (any Account)
            
            
            (fromKey, fromAcc) = try PreTransactionChecks(from)
            (toKey, toAcc) = try PreTransactionChecks(to)
            
            
            if fromKey.perms != .withdraw {
                throw accessDenied
            }
            if toKey.perms != .deposit {
                throw accessDenied
            }
//            print("Requesting withdraw of \(amount) from \(from)")
            let withdraw = Transaction.withdraw(name, amount, from, accessKey: fromKey)
            let wd = fromAcc.transact(withdraw)
            var deposit: Transaction
            var result: Transaction
            switch wd {
            case .partial(_ , let amt, _, _, _, _):
                deposit = Transaction.deposit(name, amt, to, accessKey: toKey)
                result = Transaction.transfer(amt, name, from, fromAcc.type, to, toAcc.type)
            case .withdraw(_ , let amt, _, _, _):
                deposit = Transaction.deposit(name, amt, to, accessKey: toKey)
                result = Transaction.transfer(amt, name, from, fromAcc.type, to, toAcc.type)
            case .failed(let e):
                deposit = Transaction.deposit(name, 0, to, accessKey: toKey)
                result = Transaction.failed(ERROR.transactionError("Transfer Failed: \(e)"))
            default:
                deposit = Transaction.deposit(name, 0, to, accessKey: toKey)
                result = Transaction.failed(ERROR.transactionError("Transfer Failed: Unknown Error"))
            }
            toAcc.transact(deposit)
            
            bank.logTransaction(result)
        }
        catch {
            bank.logTransaction(Transaction.failed(error as! ERROR))
            return
        }
    }
    func deposit(_ amount: Double, _ acc: String) {
        let accessDenied = ERROR.accessDenied("Invalid permissions for making deposits.")
        var accessKey: AccessKey
        var account: (any Account)
        do{
            (accessKey, account) = try PreTransactionChecks(acc)
            
            if accessKey.perms != .deposit {
                throw accessDenied
            }
        }
        catch {
            bank.logTransaction(Transaction.failed(error as! ERROR))
            return
        }
        
        let transaction = Transaction.deposit(name, amount, acc, accessKey: accessKey)
        let result = account.transact(transaction)
        
        bank.logTransaction(result)
    }
    func withdraw(_ amount: Double, _ acc: String) {
        
        do{
            let accessDenied = ERROR.accessDenied("Invalid permissions for making purchases.")
            var accessKey: AccessKey
            var account: (any Account)
            (accessKey, account) = try PreTransactionChecks(acc)
            if accessKey.perms != .withdraw {
                throw accessDenied
            }
            
            let transaction = Transaction.withdraw(name, amount, acc, accessKey: accessKey)
            let result = account.transact(transaction)
            
            bank.logTransaction(result)
        }
        catch {
            bank.logTransaction(Transaction.failed(error as! ERROR))
            return
        }
    }
    func requestBalance(_ acc: String) {
        guard let account = bank.getAccount(acc) else {
            bank.logTransaction(Transaction.failed(ERROR.accessDenied("Invalid permissions for accessing balance.")))
            return
        }
        let type = account.type
        let balance = account.balance
        guard let accessKey = accountKeys[acc] else {
            bank.logTransaction(Transaction.failed(ERROR.accessDenied("Invalid permissions for accessing balance.")))
            return
        }
        bank.logTransaction(Transaction.requestBalance(name, acc, type, balance, accessKey))
    }
    func requestBalance() {
        var sum: Double = 0
        for (_, account) in accounts {
            sum += account.balance
        }
        let result = Transaction.requestBalance(name, "All Accounts", "", sum, clientKey)
        bank.logTransaction(result)
    }
    
    
}

class Bank {
    private var allAccounts: [String: (any Account)] = [:] /// [accountNum:Account_obj]
    private var allClients: [String:Client] = [:] /// [client_name:Client_obj]
    private var transactionHist: Stack<Transaction>
    private var bankKey: AccessKey = AccessKey("ADMIN", .admin)
    
    
    private func generateAccountNumber() -> String {
        var newNum: String
        repeat {
            newNum = String(format: "%06d", Int.random(in: 0...999999))
        } while allAccounts[newNum] != nil
        
        return newNum
    }
    
    func getClient(_ name: String) -> Client? {
        return allClients[name]
    }
    func getAccount(_ num: String) -> (any Account)? {
        return allAccounts[num]
    }
    
    func CreateChecking(_ clientName: String, balance: Double, interestRate: Double, withdrawLimit: Double? = nil, overdraftFee: Double? = nil) -> String{
        if allClients[clientName] == nil  {
            allClients[clientName] = Client(clientName, self)
        }
        let client = allClients[clientName]!
        let num = generateAccountNumber()
        let newAcc = CheckingAccount(num, bankKey, interestRate, withdrawLimit, overdraftFee)
        newAcc.balance = balance
        allAccounts[num] = newAcc
        
        let ownerKey = AccessKey("owner", .admin)
        client.initAccount(newAcc, bankKey, ownerKey)
        return num
    }
    func CreateSavings(_ clientName: String, balance: Double, interestRate: Double,withdrawLimit: Double) -> String{
        if allClients[clientName] == nil  {
            allClients[clientName] = Client(clientName, self)
        }
        let client = allClients[clientName]!
        let num = generateAccountNumber()
        let newAcc = SavingsAccount(num, bankKey, interestRate, withdrawLimit)
        newAcc.balance = balance
        allAccounts[num] = newAcc
        
        let ownerKey = AccessKey("owner", .admin)
        client.initAccount(newAcc, bankKey, ownerKey)
        return num
    }
    func CreateBilling(_ clientName: String, balance: Double, interestRate: Double) -> String{
        if allClients[clientName] == nil  {
            allClients[clientName] = Client(clientName, self)
        }
        let client = allClients[clientName]!
        let num = generateAccountNumber()
        let newAcc = BillingAccount(num, bankKey, interestRate)
        newAcc.balance = balance
        allAccounts[num] = newAcc
        
        let ownerKey = AccessKey("owner", .admin)
        client.initAccount(newAcc, bankKey, ownerKey)
        return num
        
    }
    
    init () {
        self.transactionHist = Stack<Transaction>()
    }
    
    func logTransaction(_ transaction: Transaction) {
        transactionHist.push(transaction)
    }
    func addSpacer() {
        logTransaction(Transaction.spacer)
    }
    func addSection(_ header:String) {
        logTransaction(Transaction.section(header))
    }
    func applyIterest(_ accounts:[String]){
        for acc in accounts {
            if let accObj = allAccounts[acc] {
                accObj.transact(Transaction.interest(accObj.type, accObj.owners[0], acc))
            }
        }
    }
    
    
    func printLOG() {
        for i in 0..<transactionHist.count {
            print(transactionHist[i].print(self))
        }
    }
    
}

// MARK: - Test Cases
var bank = Bank()
bank.addSection("Creating Accounts")
let checking1 = bank.CreateChecking("John Doe", balance: 1000, interestRate: 0.04, overdraftFee: 5.50)
let savings1 = bank.CreateSavings("Jane Doe", balance: 2000, interestRate: 0.2, withdrawLimit: 1000)
let billing1 = bank.CreateBilling("John Doe", balance: 1500, interestRate: 0.03)

bank.addSpacer()

let checking2 = bank.CreateChecking("Totally Not A Hacker", balance: 100, interestRate: 5.0, overdraftFee: -100)

bank.addSpacer()

let employerPayroll = bank.CreateBilling("Employer Inc.", balance: 1000000, interestRate: 0.04)
let employerSavings = bank.CreateSavings("Employer Inc.", balance: 100000000, interestRate: 0.5, withdrawLimit: 100000)
let employerCapital = bank.CreateChecking("Employer Inc.", balance: 1000000, interestRate: 0.04)

let retailCapital = bank.CreateChecking("Retail inc.", balance: 100000000, interestRate: 0.04)
let restarauntCapital = bank.CreateChecking("Resteraunt inc.", balance: 100000000, interestRate: 0.04)

let onlineVendorCapital = bank.CreateChecking("BuyOnline inc.", balance: 100000, interestRate: 0.06)

// fetching clients
var employer = bank.getClient("Employer Inc.")!
var restaraunt = bank.getClient("Resteraunt inc.")!
var retail = bank.getClient("Retail inc.")!
var buyOnline = bank.getClient("BuyOnline inc.")!
var Jane = bank.getClient("Jane Doe")!
var John = bank.getClient("John Doe")!
var notHacker = bank.getClient("Totally Not A Hacker")!

// transactions
bank.addSection("Today's Transactions")
Jane.addAccount(checking1, John.accountKeys[checking1]!, .full)
Jane.spend(300, checking1, retailCapital)

bank.addSpacer()

employer.spend(10000, employerCapital, restarauntCapital)
retail.spend(15000, retailCapital, employerCapital)
restaraunt.withdraw(15000, restarauntCapital)

bank.addSpacer()

notHacker.addAccount(employerSavings, AccessKey("Hahahaha", .admin), KeyPerms.admin)
notHacker.requestBalance(employerSavings)

bank.addSpacer()

notHacker.requestBalance(checking2)
notHacker.transfer(100000000, employerSavings, checking2)
notHacker.transfer(100000, employerSavings, checking2)
notHacker.transfer(100000, employerSavings, checking2)
notHacker.transfer(100000, employerSavings, checking2)
notHacker.transfer(100000, employerSavings, checking2)
notHacker.transfer(100000, employerSavings, checking2)
notHacker.transfer(100000, employerSavings, checking2)
notHacker.transfer(100000, employerSavings, checking2)
notHacker.transfer(100000, employerSavings, checking2)
notHacker.transfer(100000, employerSavings, checking2)
notHacker.requestBalance(checking2)

bank.addSpacer()

employer.requestBalance(employerSavings)
employer.requestBalance(employerSavings)
employer.requestBalance(employerSavings)

bank.addSpacer()

employer.transfer(80000, employerCapital, employerSavings)
employer.bill(1000, employerPayroll, checking1, "employee salary")

bank.addSpacer()

notHacker.spend(183465, checking2, onlineVendorCapital)
notHacker.spend(9000, checking2, onlineVendorCapital)
notHacker.spend(85600, checking2, onlineVendorCapital)
notHacker.requestBalance(checking2)

bank.addSpacer()

bank.addSection("Final Balances")
John.requestBalance(checking1)
retail.requestBalance(retailCapital)
restaraunt.requestBalance(restarauntCapital)
employer.requestBalance(employerCapital)
employer.requestBalance(employerPayroll)
employer.requestBalance(employerSavings)
notHacker.requestBalance()

bank.printLOG()




