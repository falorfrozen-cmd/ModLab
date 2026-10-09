using System.Collections.Concurrent;
using System.Security.Cryptography;
using UAssetAPI;
using UAssetAPI.ExportTypes;
using UAssetAPI.PropertyTypes.Objects;
using UAssetAPI.PropertyTypes.Structs;
using UAssetAPI.UnrealTypes;
using UAssetAPI.Unversioned;

// Preserve the game's two existing R1 actions and all of their payloads. Add
// only a client component request, using the engine's public Game Features API.
// Original assets are extracted locally by the build script; none are checked in.
if (args.Length != 2) throw new ArgumentException("Usage: ModLabLoaderBuild <original R1.uasset> <output R1.uasset>");
var source = Path.GetFullPath(args[0]);
var output = Path.GetFullPath(args[1]);
if (source == output) throw new InvalidOperationException("The source asset must remain untouched.");
if (Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(source))) != "9CD2502A59137A87D08E6EE60D8001FF536AD980E5E06F6B5279FBF5001C569B")
    throw new InvalidOperationException("The R1 asset does not match the validated original. Do not rebuild from another loader's overlay or a new game version without inspecting it first.");
var asset = new UAsset(source, EngineVersion.VER_UE5_6);
if (asset.FolderName.ToString() != "/R1/R1" || asset.Exports.Count != 3 || !asset.HasUnversionedProperties)
    throw new InvalidOperationException("Unsupported R1 layout. Inspect the new game build before updating this adapter.");
var feature = asset.Exports[1] as RawExport ?? throw new InvalidOperationException("Expected the original unversioned feature export.");
var payload = feature.Data;
byte[] expectedPrefix = Convert.FromHexString("0005020000000300000001000000");
if (payload.Length != 87 || !payload.AsSpan(0, 14).SequenceEqual(expectedPrefix))
    throw new InvalidOperationException("R1 action-array layout changed; refusing to generate an overlay.");
var originalPayloads = asset.Exports.OfType<RawExport>().Select(e => e.Data.ToArray()).ToArray();
var preservedTail = payload.AsSpan(14).ToArray();

var schemas = new Usmap {
    Schemas = new Dictionary<string, UsmapSchema>(), EnumMap = new Dictionary<string, UsmapEnum>(),
    NameMap = [], CustomVersionContainer = [], FailedExtensions = [],
    PathsAlreadyProcessedForSchemas = new ConcurrentDictionary<string, byte>()
};
void Schema(string name, string parent, params (string Name, UsmapPropertyData Type)[] fields)
{
    var properties = new ConcurrentDictionary<int, UsmapProperty>();
    for (int i = 0; i < fields.Length; i++)
        properties[i] = new UsmapProperty(fields[i].Name, i, 0, 1, fields[i].Type);
    schemas.Schemas[name] = new UsmapSchema(name, parent, fields.Length, properties, false, "", false);
}
Schema("Object", "");
Schema("GameFeatureAction", "Object");
Schema("GameFeatureAction_AddComponents", "GameFeatureAction", ("ComponentList", new UsmapArrayData(UsmapPropertyType.ArrayProperty) { InnerType = new UsmapStructData("GameFeatureComponentEntry") }));
Schema("GameFeatureComponentEntry", "",
    ("ActorClass", new UsmapPropertyData(UsmapPropertyType.SoftObjectProperty)),
    ("ComponentClass", new UsmapPropertyData(UsmapPropertyType.SoftObjectProperty)),
    ("bClientComponent", new UsmapPropertyData(UsmapPropertyType.BoolProperty)),
    ("bServerComponent", new UsmapPropertyData(UsmapPropertyType.BoolProperty)),
    ("AdditionFlags", new UsmapPropertyData(UsmapPropertyType.ByteProperty)));
asset.Mappings = schemas;
FName N(string name) => new(asset, name);
var featurePackage = asset.Imports.FindIndex(i => i.ObjectName.ToString() == "/Script/GameFeatures");
if (featurePackage < 0) throw new InvalidOperationException("Game Features package import missing.");
asset.Imports.Add(new Import("/Script/CoreUObject", "Class", new FPackageIndex(-featurePackage - 1), "GameFeatureAction_AddComponents", false, asset));
var actionClass = new FPackageIndex(-asset.Imports.Count);
asset.Imports.Add(new Import("/Script/GameFeatures", "GameFeatureAction_AddComponents", new FPackageIndex(-featurePackage - 1), "Default__GameFeatureAction_AddComponents", false, asset));
var actionTemplate = new FPackageIndex(-asset.Imports.Count);
SoftObjectPropertyData Soft(string name, string package, string objectName)
{
    var path = new FSoftObjectPath(N(package), N(objectName), new FString(""));
    return new SoftObjectPropertyData(N(name)) { Value = path };
}
var entry = new StructPropertyData(N("0"), N("GameFeatureComponentEntry"))
{
    Value = new List<PropertyData> {
        Soft("ActorClass", "/Script/Engine", "PlayerController"),
        Soft("ComponentClass", "/Game/Mods/ModLabLoader/LoaderComponent", "LoaderComponent_C"),
        new BoolPropertyData(N("bClientComponent")) { Value = true },
        new BoolPropertyData(N("bServerComponent")) { Value = true },
        new BytePropertyData(N("AdditionFlags")) { Value = 0 }
    }
};
var request = new NormalExport(asset, [])
{
    ObjectName = N("ModLabLoader_AddComponents"), OuterIndex = new FPackageIndex(2),
    ClassIndex = actionClass, TemplateIndex = actionTemplate, SuperIndex = new FPackageIndex(0),
    ObjectFlags = EObjectFlags.RF_Public | EObjectFlags.RF_Transactional,
    Data = new List<PropertyData> { new ArrayPropertyData(N("ComponentList")) { ArrayType = N("StructProperty"), Value = [entry] } },
    SerializationBeforeSerializationDependencies = [],
    CreateBeforeSerializationDependencies = [],
    SerializationBeforeCreateDependencies = [actionClass, actionTemplate],
    CreateBeforeCreateDependencies = [new FPackageIndex(2)], Extras = []
};
asset.Exports.Add(request);
asset.DependsMap.Add([]);
using (var stream = new MemoryStream())
using (var writer = new BinaryWriter(stream))
{
    writer.Write(payload.AsSpan(0, 2)); writer.Write(3); // Actions now has three entries.
    writer.Write(payload.AsSpan(6, 8)); writer.Write(4); // Original entries 3,1, then our export 4.
    writer.Write(preservedTail);
    feature.Data = stream.ToArray();
}
feature.CreateBeforeSerializationDependencies.Add(new FPackageIndex(4));
typeof(UAsset).GetField("NamesReferencedFromExportDataCount", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!
    .SetValue(asset, asset.GetNameMapIndexList().Count);
Directory.CreateDirectory(Path.GetDirectoryName(output)!);
asset.Write(output);

var roundtrip = new UAsset(output, EngineVersion.VER_UE5_6, schemas);
if (roundtrip.Exports.Count != 4 || roundtrip.Exports[3] is not NormalExport check || check.Data.Count != 1)
    throw new InvalidOperationException("Generated action did not survive serialization.");
for (int i = 0; i < 3; i++)
{
    var actual = (roundtrip.Exports[i] as RawExport)?.Data ?? throw new InvalidOperationException("Original action payload unexpectedly interpreted.");
    if (i != 1 && !actual.SequenceEqual(originalPayloads[i])) throw new InvalidOperationException("A native action payload changed.");
    if (i == 1 && !actual.AsSpan(18).SequenceEqual(preservedTail)) throw new InvalidOperationException("Native feature scan settings changed.");
}
Console.WriteLine($"PASS native R1 actions and scan settings preserved; one component request added. Source SHA256 {Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(source)))}");
