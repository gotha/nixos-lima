{ config, lib, ... }:
with lib;
let
  filterAttrsListsRecursive = pred: set:
    # also recur into lists (not only attrs)
    listToAttrs (concatMap (name:
      let v = set.${name};
      in if pred name v then
        [
          (nameValuePair name (if isAttrs v then
            filterAttrsListsRecursive pred v
          else if (isList v) then
            map (filterAttrsListsRecursive pred) v
          else
            v))
        ]
      else
        [ ]) (attrNames set));

  cfg = config.lima;
  cleanSettings = filterAttrsListsRecursive (n: v: v != null) cfg.settings;
in {
  options.lima = {
    configFile = mkOption {
      type = types.anything;
      description = "lima configuration yaml/json file";
      # use builtins.toJSON instead of settinsFormat.generate due to architecture change
      default = builtins.toFile "lima.yaml" (builtins.toJSON cleanSettings);
    };
  };
}
