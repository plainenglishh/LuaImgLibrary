local fs = require("@lune/fs");
local process = require("@lune/process");
local serde = require("@lune/serde");


--// Cleanup Previous //--

if fs.isDir("./out") then
    fs.removeDir("./out");
end


--// Create Sourcemap //--

local sourcemap = process.spawn("rojo", {"sourcemap"});
if sourcemap.ok then
    fs.writeFile("./sourcemap.json", sourcemap.stdout);
else
    error(sourcemap.stderr);
end


--// Create Target Dirs //--

fs.writeDir("./out/");        -- Output folder.
--fs.writeDir("./out/working"); -- Output folder.

fs.writeDir("./out/roblox");  -- Compiled model files for roblox.
fs.writeDir("./out/lune");    -- Package for lune
fs.writeDir("./out/rojo");    -- Package for rojo


fs.copy("./src", "./out/working");

fs.writeFile("./darklua.json", serde.encode("json", {
    bundle = {
        require_mode = "path",
        excludes = {"@lune/**"}
    },
    rules = {
        {
            rule = "append_text_comment",
            text = "--!nocheck"
        },
        "remove_method_definition",
        "rename_variables",
        "remove_types",
        "remove_compound_assignment",
        "remove_interpolated_string"
    }
}));

--[[
{
    "bundle": {
        "require_mode": "path",
        "excludes": ["@lune/**"],
    },
    "rules": [
        {
            "rule": "append_text_comment",
            "text: "--!nocheck"
        }
    ]
}
]]

--// Rojo //--

fs.copy("./runtime/roblox.lua", "./out/working/util/runtime.lua");
print(process.spawn("darklua", {"process", "--config", "darklua.json", "./out/working/init.lua", "./out/rojo/RbxImageLibrary.lua"}));
print(process.spawn("darklua", {"minify", "./out/rojo/RbxImageLibrary.lua", "./out/rojo/RbxImageLibrary.lua"}));

--// Lune //--

fs.copy("./runtime/lune.lua", "./out/working/util/runtime.lua", true);
print(process.spawn("darklua", {"process", "--config", "darklua.json", "./out/working/init.lua", "./out/lune/RbxImageLibrary.lua"}));
print(process.spawn("darklua", {"minify", "./out/lune/RbxImageLibrary.lua", "./out/lune/RbxImageLibrary.lua"}));


--// Roblox //--

fs.writeFile("./out/default.project.json", serde.encode("json", {
    name = "RbxImageLibrary",
    tree = {
        ["$path"] = "./working"
    }
}));

print(process.spawn("rojo", {"build", "out/", "--output", "out/roblox/RbxImageLib.rbxmx"}));
process.spawn("rojo", {"build", "out/", "--output", "out/roblox/RbxImageLib.rbxm"});
fs.removeFile("./out/default.project.json");


--// Clean //--

fs.removeFile("./darklua.json");
