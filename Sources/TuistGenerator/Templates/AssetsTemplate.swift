// swiftformat:disable wrap
extension SynthesizedResourceInterfaceTemplates {
    static let assetsTemplate = """
    // swiftlint:disable:this file_name
    // swiftlint:disable all
    // swift-format-ignore-file
    // swiftformat:disable all
    // Generated using tuist — https://github.com/tuist/tuist

    {% if catalogs %}
    {% set enumName %}{{param.name}}Asset{% endset %}
    {% set arResourceGroupType %}{{param.name}}ARResourceGroup{% endset %}
    {% set colorType %}{{param.name}}Colors{% endset %}
    {% set dataType %}{{param.name}}Data{% endset %}
    {% set imageType %}{{param.name}}Images{% endset %}
    {% set forceNamespaces %}{{param.forceProvidesNamespaces|default:"false"}}{% endset %}
    {% set bundleToken %}{{param.name}}Resources{% endset %}
    {% set accessModifier %}{% if param.publicAccess %}public{% else %}internal{% endif %}{% endset %}
    #if os(macOS)
      import AppKit
    #elseif os(iOS)
    {% if resourceCount.arresourcegroup > 0 %}
      import ARKit
    {% endif %}
      import UIKit
    #elseif os(tvOS) || os(watchOS)
      import UIKit
    #endif
    #if canImport(SwiftUI)
      import SwiftUI
    #endif

    // MARK: - Asset Catalogs

    {% macro enumBlock assets %}
      {% call casesBlock assets %}
      {% if param.allValues %}

      {% if resourceCount.arresourcegroup > 0 %}
      {{accessModifier}} static let allResourceGroups: [{{arResourceGroupType}}] = [
        {% filter indent:2 %}{% call allValuesBlock assets "arresourcegroup" "" %}{% endfilter %}
      ]
      {% endif %}
      {% if resourceCount.color > 0 %}
      {{accessModifier}} static let allColors: [{{colorType}}] = [
        {% filter indent:2 %}{% call allValuesBlock assets "color" "" %}{% endfilter %}
      ]
      {% endif %}
      {% if resourceCount.data > 0 %}
      {{accessModifier}} static let allDataAssets: [{{dataType}}] = [
        {% filter indent:2 %}{% call allValuesBlock assets "data" "" %}{% endfilter %}
      ]
      {% endif %}
      {% if resourceCount.image > 0 %}
      {{accessModifier}} static let allImages: [{{imageType}}] = [
        {% filter indent:2 %}{% call allValuesBlock assets "image" "" %}{% endfilter %}
      ]
      {% endif %}
      {% endif %}
    {% endmacro %}
    {% macro casesBlock assets %}
      {% for asset in assets %}
      {% if asset.type == "arresourcegroup" %}
      {{accessModifier}} static let {{asset.name|swiftIdentifier:"pretty"|lowerFirstWord|escapeReservedKeywords}} = {{arResourceGroupType}}(name: "{{asset.value}}")
      {% elif asset.type == "color" %}
      {{accessModifier}} static let {{asset.name|swiftIdentifier:"pretty"|lowerFirstWord|escapeReservedKeywords}} = {{colorType}}(name: "{{asset.value}}")
      {% elif asset.type == "data" %}
      {{accessModifier}} static let {{asset.name|swiftIdentifier:"pretty"|lowerFirstWord|escapeReservedKeywords}} = {{dataType}}(name: "{{asset.value}}")
      {% elif asset.type == "image" %}
      {{accessModifier}} static let {{asset.name|swiftIdentifier:"pretty"|lowerFirstWord|escapeReservedKeywords}} = {{imageType}}(name: "{{asset.value}}")
      {% elif asset.type == "symbol" %}
      {{accessModifier}} static let {{asset.name|swiftIdentifier:"pretty"|lowerFirstWord|escapeReservedKeywords}} = {{imageType}}(name: "{{asset.value}}")
      {% elif asset.items and ( forceNamespaces == "true" or asset.isNamespaced == "true" ) %}
      {{accessModifier}} enum {{asset.name|swiftIdentifier:"pretty"|escapeReservedKeywords}}: Sendable {
        {% filter indent:2 %}{% call casesBlock asset.items %}{% endfilter %}
      }
      {% elif asset.items %}
      {% call casesBlock asset.items %}
      {% endif %}
      {% endfor %}
    {% endmacro %}
    {% macro allValuesBlock assets filter prefix %}
      {% for asset in assets %}
      {% if asset.type == filter %}
      {{prefix}}{{asset.name|swiftIdentifier:"pretty"|lowerFirstWord|escapeReservedKeywords}},
      {% elif asset.items and ( forceNamespaces == "true" or asset.isNamespaced == "true" ) %}
      {% set prefix2 %}{{prefix}}{{asset.name|swiftIdentifier:"pretty"|escapeReservedKeywords}}.{% endset %}
      {% call allValuesBlock asset.items filter prefix2 %}
      {% elif asset.items %}
      {% call allValuesBlock asset.items filter prefix %}
      {% endif %}
      {% endfor %}
    {% endmacro %}
    {{accessModifier}} enum {{enumName}}: Sendable {
      {% if catalogs.count > 1 or param.forceFileNameEnum %}
      {% for catalog in catalogs %}
      {{accessModifier}} enum {{catalog.name|swiftIdentifier:"pretty"|escapeReservedKeywords}} {
        {% filter indent:2 %}{% call enumBlock catalog.assets %}{% endfilter %}
      }
      {% endfor %}
      {% else %}
      {% call enumBlock catalogs.first.assets %}
      {% endif %}
    }

    // MARK: - Implementation Details

    {% if resourceCount.arresourcegroup > 0 %}
    {{accessModifier}} struct {{arResourceGroupType}}: Sendable {
      {{accessModifier}} let name: String

      #if os(iOS)
      @available(iOS 11.3, *)
      {{accessModifier}} var referenceImages: Set<ARReferenceImage> {
        return ARReferenceImage.referenceImages(in: self)
      }

      @available(iOS 12.0, *)
      {{accessModifier}} var referenceObjects: Set<ARReferenceObject> {
        return ARReferenceObject.referenceObjects(in: self)
      }
      #endif
    }

    #if os(iOS)
    @available(iOS 11.3, *)
    {{accessModifier}} extension ARReferenceImage {
      static func referenceImages(in asset: {{arResourceGroupType}}) -> Set<ARReferenceImage> {
        let bundle = Bundle.module
        return referenceImages(inGroupNamed: asset.name, bundle: bundle) ?? Set()
      }
    }

    @available(iOS 12.0, *)
    {{accessModifier}} extension ARReferenceObject {
      static func referenceObjects(in asset: {{arResourceGroupType}}) -> Set<ARReferenceObject> {
        let bundle = Bundle.module
        return referenceObjects(inGroupNamed: asset.name, bundle: bundle) ?? Set()
      }
    }
    #endif

    {% endif %}
    {% if resourceCount.color > 0 %}
    {{accessModifier}} final class {{colorType}}: Sendable {
      {{accessModifier}} let name: String

      #if os(macOS)
      {{accessModifier}} typealias Color = NSColor
      #elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
      {{accessModifier}} typealias Color = UIColor
      #endif

      @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, visionOS 1.0, *)
      {{accessModifier}} var color: Color {
        guard let color = Color(asset: self) else {
          fatalError("Unable to load color asset named \\(name).")
        }
        return color
      }

      #if canImport(SwiftUI)
      @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
      {{accessModifier}} var swiftUIColor: SwiftUI.Color {
          return SwiftUI.Color(asset: self)
      }
      #endif

      fileprivate init(name: String) {
        self.name = name
      }
    }

    {{accessModifier}} extension {{colorType}}.Color {
      @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, visionOS 1.0, *)
      convenience init?(asset: {{colorType}}) {
        let bundle = Bundle.module
        #if os(iOS) || os(tvOS) || os(visionOS)
        self.init(named: asset.name, in: bundle, compatibleWith: nil)
        #elseif os(macOS)
        self.init(named: NSColor.Name(asset.name), bundle: bundle)
        #elseif os(watchOS)
        self.init(named: asset.name)
        #endif
      }
    }

    #if canImport(SwiftUI)
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
    {{accessModifier}} extension SwiftUI.Color {
      init(asset: {{colorType}}) {
        let bundle = Bundle.module
        self.init(asset.name, bundle: bundle)
      }
    }
    #endif

    {% endif %}
    {% if resourceCount.data > 0 %}
    {{accessModifier}} struct {{dataType}}: Sendable {
      {{accessModifier}} let name: String

      #if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
      @available(iOS 9.0, macOS 10.11, visionOS 1.0, *)
      {{accessModifier}} var data: NSDataAsset {
        guard let data = NSDataAsset(asset: self) else {
          fatalError("Unable to load data asset named \\(name).")
        }
        return data
      }
      #endif
    }

    #if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
    @available(iOS 9.0, macOS 10.11, visionOS 1.0, *)
    {{accessModifier}} extension NSDataAsset {
      convenience init?(asset: {{dataType}}) {
        let bundle = Bundle.module
        #if os(iOS) || os(tvOS) || os(visionOS)
        self.init(name: asset.name, bundle: bundle)
        #elseif os(macOS)
        self.init(name: NSDataAsset.Name(asset.name), bundle: bundle)
        #endif
      }
    }
    #endif

    {% endif %}
    {% if resourceCount.image > 0 or resourceCount.symbol > 0 %}
    {{accessModifier}} struct {{imageType}}: Sendable {
      {{accessModifier}} let name: String

      #if os(macOS)
      {{accessModifier}} typealias Image = NSImage
      #elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
      {{accessModifier}} typealias Image = UIImage
      #endif

      {{accessModifier}} var image: Image {
        let bundle = Bundle.module
        #if os(iOS) || os(tvOS) || os(visionOS)
        let image = Image(named: name, in: bundle, compatibleWith: nil)
        #elseif os(macOS)
        let image = bundle.image(forResource: NSImage.Name(name))
        #elseif os(watchOS)
        let image = Image(named: name)
        #endif
        guard let result = image else {
          fatalError("Unable to load image asset named \\(name).")
        }
        return result
      }

      #if canImport(SwiftUI)
      @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
      {{accessModifier}} var swiftUIImage: SwiftUI.Image {
        SwiftUI.Image(asset: self)
      }
      #endif
    }

    #if canImport(SwiftUI)
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
    {{accessModifier}} extension SwiftUI.Image {
      init(asset: {{imageType}}) {
        let bundle = Bundle.module
        self.init(asset.name, bundle: bundle)
      }

      init(asset: {{imageType}}, label: Text) {
        let bundle = Bundle.module
        self.init(asset.name, bundle: bundle, label: label)
      }

      init(decorative asset: {{imageType}}) {
        let bundle = Bundle.module
        self.init(decorative: asset.name, bundle: bundle)
      }
    }
    #endif

    {% endif %}
    {% else %}
    // No assets found
    {% endif %}
    // swiftformat:enable all
    // swiftlint:enable all

    """
}
