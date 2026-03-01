import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

private let paymentCodeContext = CIContext()

struct PaymentCodeScreen: View {
    @EnvironmentObject private var loginState: AppLoginState

    @State private var barcodeNumber = ""
    @State private var qrImage: UIImage?
    @State private var barcodeImage: UIImage?
    @State private var message = ""
    @State private var isLoading = true
    @State private var countdown = 12
    @State private var refreshToken = UUID()

    private let api = PaymentCodeAPI()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                Group {
                    if isLoading {
                        ProgressView("正在加载付款码...")
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if let qrImage, let barcodeImage, !barcodeNumber.isEmpty {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 240, maxHeight: 240)

                        Image(uiImage: barcodeImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 320, maxHeight: 84)

                        Text(barcodeNumber)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        EmptyPlaceholder(title: "暂无付款码", subtitle: "点击刷新重试")
                    }
                }

                HStack(spacing: 12) {
                    StatusBadge(text: "\(countdown)s", color: .blue)
                    Button("手动刷新") {
                        refreshToken = UUID()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("付款码")
        .task(id: refreshToken) {
            await startRefreshLoop()
        }
    }

    private func startRefreshLoop() async {
        isLoading = true
        message = "正在认证支付系统..."

        guard await loginState.ensureLogin(type: .jwxt) else {
            isLoading = false
            message = "请先登录教务系统"
            return
        }

        do {
            try await api.authenticate()
            message = ""
        } catch {
            isLoading = false
            message = "认证失败: \(error.localizedDescription)"
            return
        }

        while !Task.isCancelled {
            do {
                let code = try await api.getBarCode()
                barcodeNumber = code
                qrImage = makeQRCode(code)
                barcodeImage = makeCode128(code)
                isLoading = false
                message = ""
            } catch {
                isLoading = false
                message = "刷新失败: \(error.localizedDescription)"
            }

            countdown = 12
            while countdown > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                countdown -= 1
            }
        }
    }

    private func makeQRCode(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }

        let scale: CGFloat = 10
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = paymentCodeContext.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func makeCode128(_ text: String) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(text.utf8)
        filter.quietSpace = 7
        guard let output = filter.outputImage else { return nil }

        let transformed = output.transformed(by: CGAffineTransform(scaleX: 3.2, y: 80))
        guard let cgImage = paymentCodeContext.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
