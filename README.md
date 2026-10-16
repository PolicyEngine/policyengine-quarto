# policyengine-quarto

Quarto formats for PolicyEngine working papers, with local static fonts for
hermetic PDF and HTML rendering.

```sh
quarto add PolicyEngine/policyengine-quarto
```

Use `policyengine-paper-pdf` and `policyengine-paper-html` in the document
`format` block.

Metadata:

- `wordmark`: the PolicyEngine wordmark heads the PDF and HTML title blocks;
  defaults to `true`. Set `wordmark: false` to omit it from a document, or set
  it under one format to omit it there only. When no author lists an
  affiliation, the title block falls back to a "PolicyEngine" byline; the
  wordmark replaces that fallback. Author affiliations always print.
- `kicker`: short register line above the title; defaults to `WORKING PAPER`.
- `revision`: revision number shown with the ISO document date.
- `status`: Markdown body for the status banner; the format supplies its label.
- `theme`: PolicyEngine is the sole v1 theme and is already selected. Leave
  Quarto's HTML `theme` override unset; shared values live in
  `theme-policyengine.yml` so a future format can reuse the partials.

See `example/paper.qmd` for a minimal two-format paper.

Rendering copies the format's resources beside the document: `fonts/` and
`policyengine-wordmark.pdf` for PDF, `policyengine-wordmark.svg` for HTML.
Projects with an output directory also copy the SVG beside each page. Add these
copies to `.gitignore`.

## Development

`scripts/check.sh` validates the SVG assets, confirms the committed PDF
wordmark still matches the SVG, and renders test documents in every paper
format with and without the wordmark. It needs Quarto, XeLaTeX, xmllint,
rsvg-convert, pdftoppm and ImageMagick; CI runs it on every pull request.

The PDF wordmark is a vector conversion of
`_extensions/policyengine/assets/policyengine-wordmark.svg`, committed so
rendering needs no conversion step. After editing the SVG, run
`scripts/build-wordmark-pdf.sh` and commit both files.

## License

Code in this repository is released under the [MIT License](LICENSE). Original text and figures are released under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) with attribution to PolicyEngine. Third-party data and materials keep their own terms.
