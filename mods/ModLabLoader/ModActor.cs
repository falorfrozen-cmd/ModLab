using System.Collections.Generic;
using NeoRune;
using UE.AssetRegistry;
using UE.Engine;

namespace ModLabLoader;

/// <summary>One bounded startup pass per world. No tick, polling process or DLL injection.</summary>
public class ModActor : AActor
{
    List<string> candidates;
    List<AActor> started;
    int cursor;
    bool stopped;
    double startedAt;
    List<string> disabled;

    protected override void ReceiveBeginPlay()
    {
        candidates = new List<string>();
        started = new List<AActor>();
        startedAt = World.RealTime(this);
        disabled = new List<string>();
        if (UKismetSystemLibrary.ParseParamValue(UKismetSystemLibrary.GetCommandLine(), "ModLabLoaderSkip=", out var skip))
        {
            disabled = UKismetStringLibrary.ParseIntoArray(skip, ",", true);
            Trace("requested skip " + skip);
        }
        // Scan the mounted mod namespace only, never the game's complete asset registry.
        var registry = UAssetRegistryHelpers.GetAssetRegistry();
        if (registry != null)
        {
            if (!registry.HasAssets("/Game/Mods", true))
                registry.ScanPathsSynchronous(new List<string> { "/Game/Mods" }, false, true);
            registry.GetAssetsByPath("/Game/Mods", out var assets, true, false);
            foreach (var asset in assets)
            {
                string name = UKismetStringLibrary.Conv_NameToString(asset.AssetName);
                string package = UKismetStringLibrary.Conv_NameToString(asset.PackageName);
                if (name == "ModActor" || name == "ModActor_C")
                {
                    string entry = package + ".ModActor_C";
                    if (!package.StartsWith("/Game/Mods/ModLabLoader/") && !package.Contains("BlueprintLoader") && !candidates.Contains(entry))
                        candidates.Add(entry);
                }
            }
            registry.GetSubPaths("/Game/Mods", out var paths, false);
            foreach (var path in paths)
                if (path != "/Game/Mods/ModLabLoader" && !path.Contains("BlueprintLoader"))
                {
                    string entry = path + "/ModActor.ModActor_C";
                    if (!candidates.Contains(entry)) candidates.Add(entry);
                }
            Trace($"registry assets={assets.Count}; folders={paths.Count}; loading={registry.IsLoadingAssets()}");
        }
        Trace($"begin {World.LevelName(this)}; candidates={candidates.Count}");
        Timer.Start(this, nameof(StartNext), .01f, false);
    }

    void StartNext()
    {
        if (stopped) return;
        if (cursor >= candidates.Count || cursor >= 128)
        {
            Trace($"ready {World.LevelName(this)}; started={started.Count}; seconds={World.RealTime(this) - startedAt}");
            candidates.Clear();
            return;
        }
        string path = candidates[cursor];
        cursor++;
        string id = path.Replace("/Game/Mods/", "").Replace("/ModActor.ModActor_C", "");
        if (disabled.Contains(id))
        {
            Trace("disabled " + id);
            Timer.Start(this, nameof(StartNext), .01f, false);
            return;
        }
        var type = Unreal.LoadClass<AActor>(path);
        if (type != null)
        {
            var existing = World.FindAll(this, type);
            if (existing.Count == 0)
            {
                var actor = World.Spawn(this, type, new UE.CoreUObject.FVector());
                if (actor != null) { started.Add(actor); Trace("started " + path); }
                else Trace("spawn failed " + path);
            }
            else Trace("already present " + path);
        }
        else Trace("missing optional entry " + path);
        Timer.Start(this, nameof(StartNext), .01f, false);
    }

    void Trace(string message)
    {
        if (UKismetSystemLibrary.GetCommandLine().Contains("-ModLabLoaderDiagnostics"))
            Log.Write("[ModLab Loader] " + message);
    }

    protected override void ReceiveEndPlay(EEndPlayReason reason)
    {
        stopped = true;
        UKismetSystemLibrary.K2_ClearTimer(this, nameof(StartNext));
        // The world owns the actors. Let their native EndPlay run exactly once.
        if (started != null) started.Clear();
        if (candidates != null) candidates.Clear();
        if (disabled != null) disabled.Clear();
    }
}
