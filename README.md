# policyengine-quarto

Quarto formats for PolicyEngine working papers, with local static fonts for
hermetic PDF and HTML rendering.

```sh
quarto add PolicyEngine/policyengine-quarto
```

Use `policyengine-paper-pdf` and `policyengine-paper-html` in the document
`format` block.

Metadata:

- `kicker`: short register line above the title; defaults to `WORKING PAPER`.
- `revision`: revision number shown with the ISO document date.
- `status`: Markdown body for the status banner; the format supplies its label.
- `theme`: PolicyEngine is the sole v1 theme and is already selected. Leave
  Quarto's HTML `theme` override unset; shared values live in
  `theme-policyengine.yml` so a future format can reuse the partials.

See `example/paper.qmd` for a minimal two-format paper.

## License

Code in this repository is released under the [MIT License](LICENSE). Original text and figures are released under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) with attribution to PolicyEngine. Third-party data and materials keep their own terms.
