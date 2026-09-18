import Foundation

extension Double {
    var currencyEUR: String {
        formatted(.currency(code: "EUR"))
    }
}
