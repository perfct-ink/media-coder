import SwiftUI

/// Source drawing used to generate all logo and app icon assets.
struct FilmIconDrawing: View {
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

/// Use the identical rendered logo on every app surface.
struct FilmIconArtwork: View {
    var size: CGFloat = 52
    var body: some View {
        #if SWIFT_PACKAGE
        Image("AppLogo", bundle: .module)
            .resizable().interpolation(.high).scaledToFit()
            .frame(width: size, height: size).accessibilityLabel("Media Coder")
        #else
        Image("AppLogo")
            .resizable().interpolation(.high).scaledToFit()
            .frame(width: size, height: size).accessibilityLabel("Media Coder")
        #endif
    }
}
