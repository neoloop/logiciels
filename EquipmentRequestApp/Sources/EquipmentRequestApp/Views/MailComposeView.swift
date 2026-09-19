import SwiftUI
import MessageUI

/// Enveloppe SwiftUI de MFMailComposeViewController, pré-rempli avec le PDF de la
/// demande. L'utilisateur reste maître de l'envoi : la feuille Mail s'ouvre déjà
/// remplie et l'app n'envoie jamais de mail sans confirmation.
struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let ccRecipients: [String]
    let subject: String
    let body: String
    let attachmentData: Data
    let attachmentFilename: String
    let onFinish: (MFMailComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(recipients)
        controller.setCcRecipients(ccRecipients)
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        controller.addAttachmentData(attachmentData, mimeType: "application/pdf", fileName: attachmentFilename)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void

        init(onFinish: @escaping (MFMailComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) {
                self.onFinish(result)
            }
        }
    }
}
