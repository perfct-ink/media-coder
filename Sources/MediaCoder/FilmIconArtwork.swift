import SwiftUI

/// Shared artwork for the window header and the macOS app icon.
struct FilmIconArtwork: View {
    var size: CGFloat = 52
    var body: some View {
        Image(systemName: "film.stack.fill")
            .font(.system(size: size / 2))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(red: 0.25, green: 0.40, blue: 0.95).gradient,
                        in: RoundedRectangle(cornerRadius: size * 14 / 52))
    }
}
