{ ... }:

{
  mapSubdirsWithFile =
    {
      dir,
      fileName,
      missingMessage,
      value,
    }:
    let
      entries = builtins.readDir dir;
      names = builtins.filter (name: entries.${name} == "directory") (
        builtins.attrNames entries
      );
      requireFile =
        name:
        let
          path = dir + "/${name}/${fileName}";
        in
        if builtins.pathExists path then
          path
        else
          throw (missingMessage name);
    in
    builtins.listToAttrs (
      map (
        name:
        let
          path = requireFile name;
        in
        builtins.seq path {
          inherit name;
          value = value name path;
        }
      ) names
    );
}
