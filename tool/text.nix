{ lib, ... }:

with lib;

rec {
  /**
    Return whether a value should be rendered.
  */
  isNonEmpty = value: value != null && value != "" && value != [ ] && value != { };

  /**
    Split text into lines.
  */
  splitLines = text: splitString "\n" text;

  /**
    Join lines with newlines.
  */
  joinLines = lines: concatStringsSep "\n" lines;

  /**
    Join non-empty text sections with one blank line between sections.
  */
  joinSections = sections: concatStringsSep "\n\n" (filter isNonEmpty sections);

  /**
    Indent non-empty lines by one tab.
  */
  indentLines = lines: map (line: if line == "" then "" else "\t${line}") lines;

  /**
    Render a string token with JSON quoting.
  */
  quoteToken = value: builtins.toJSON value;

  /**
    Render a brace-delimited text block.
  */
  renderBraceBlock =
    header: body:
    let
      opener = if header == "" then "{" else "${header} {";
      bodyLines = if body == "" then [ ] else indentLines (splitLines body);
    in
    joinLines ([ opener ] ++ bodyLines ++ [ "}" ]);
}
