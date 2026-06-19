import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CardThumbnail: View {
    @EnvironmentObject private var app: AppModel

    let card: Card
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColor.surfaceContainer)
                AsyncImage(url: card.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(AppColor.onSurfaceDimmer)
                    default:
                        ProgressView()
                            .tint(AppColor.primary)
                    }
                }
                .id("card-\(card.imageURL?.absoluteString ?? card.slug)-\(app.imageCacheVersion)")
                .padding(1)
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct HeroTile: View {
    @EnvironmentObject private var app: AppModel

    let cardId: String?
    let classSlug: String?
    var verticalFocus: CGFloat = 0.3

    var body: some View {
        ZStack {
            LinearGradient(colors: [AppColor.classColor(classSlug), AppColor.surfaceContainer], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let imageName = DefaultHeroes.imageName(cardId: cardId, classSlug: classSlug),
               let image = UIImage(named: imageName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.08)
            } else if let cardId, let url = URL(string: "https://art.hearthstonejson.com/v1/512x/\(cardId).webp") {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(1.08)
                    }
                }
                .id("hero-\(url.absoluteString)-\(app.imageCacheVersion)")
            }
        }
        .clipped()
    }
}

struct CardArtStrip: View {
    @EnvironmentObject private var app: AppModel

    let card: Card

    var body: some View {
        ZStack(alignment: .leading) {
            AppColor.surfaceContainer
            AsyncImage(url: card.cropImageURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.65)
                        .offset(y: -10)
                }
            }
            .id("crop-\(card.cropImageURL?.absoluteString ?? card.slug)-\(app.imageCacheVersion)")
            LinearGradient(colors: [.black.opacity(0.82), .clear], startPoint: .leading, endPoint: .trailing)
        }
        .clipped()
    }
}

struct BackToolbarButton: View {
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColor.onSurface)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.tr("Back"))
        .accessibilityIdentifier(accessibilityIdentifier ?? "back")
    }
}

struct ManaGem: View {
    let cost: Int
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x82D9FF), Color(hex: 0x2456D8)], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
            Text("\(cost)")
                .font(.system(size: size * 0.48, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
    }
}

struct DeckCardRow: View {
    let entry: DeckCardEntry
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                ManaGem(cost: entry.card.manaCost, size: 24)
                ZStack(alignment: .leading) {
                    CardArtStrip(card: entry.card)
                    Text(entry.card.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                }
                .frame(height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                if entry.card.isLegendary {
                    Text("*")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColor.rarityColor("legendary"))
                        .frame(width: 28)
                } else {
                    Text("x\(entry.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.onSurfaceDim)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColor.surfaceContainerHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .frame(height: 42)
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.onSurfaceDim)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(AppColor.onSurfaceDim)
                        .lineLimit(1)
                }
                TextField("", text: $text)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppColor.onSurface)
            }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.onSurfaceDimmer)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(AppColor.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }
}

struct ManaChips: View {
    let selected: Set<Int>
    let onToggle: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0...7, id: \.self) { cost in
                let isSelected = selected.contains(cost)
                Button {
                    onToggle(cost)
                } label: {
                    Text(cost == 7 ? "7+" : "\(cost)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? AppColor.primary : AppColor.onSurfaceDim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(isSelected ? AppColor.primarySoft : AppColor.surfaceContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isSelected ? AppColor.primary : AppColor.outlineSoft, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ClassChips: View {
    let selected: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ClassLabels.order + ["neutral"], id: \.self) { slug in
                    let isSelected = selected.contains(slug)
                    Button {
                        onToggle(slug)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppColor.classColor(slug))
                                .frame(width: 8, height: 8)
                            Text(ClassLabels.short(slug))
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(isSelected ? AppColor.primary : AppColor.onSurfaceDim)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(isSelected ? AppColor.primarySoft : AppColor.surfaceContainer)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isSelected ? AppColor.primary : AppColor.outlineSoft, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 16)
    }
}

struct FormatChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(AppColor.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColor.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct EmptyStateView: View {
    let title: String
    let bodyText: String
    var icon: String = "rectangle.stack"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(AppColor.onSurfaceDimmer)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.onSurface)
            Text(bodyText)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.onSurfaceDim)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? AppColor.onPrimary : AppColor.onSurfaceDimmer)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isEnabled ? AppColor.primary.opacity(configuration.isPressed ? 0.78 : 1) : AppColor.surfaceContainerHighest)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct IconCircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColor.onSurface)
                .frame(width: 40, height: 40)
                .background(AppColor.surfaceContainer)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func hideKeyboardOnTap() -> some View {
        onTapGesture {
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
        }
    }
}
