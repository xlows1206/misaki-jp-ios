Pod::Spec.new do |s|
  s.name         = "MisakiJP"
  s.version      = "0.1.0"
  s.summary      = "Japanese Grapheme-to-Phoneme library for iOS - port of Python misaki"
  s.description  = <<-DESC
                   MisakiJP is a Swift port of the misaki Python library.
                   It provides Japanese text normalization, number-to-kana conversion,
                   and G2P (Grapheme-to-Phoneme) conversion compatible with Kokoro TTS.
                   DESC
  s.homepage     = "https://github.com/hexgrad/misaki-jp-ios"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Author" => "author@example.com" }
  s.source       = { :git => "local", :tag => s.version.to_s }
  
  s.ios.deployment_target = "14.0"
  s.osx.deployment_target = "11.0"
  
  s.source_files = "Sources/MisakiJP/**/*.swift"
  s.swift_version = "5.9"
end
