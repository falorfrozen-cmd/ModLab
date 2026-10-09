using NeoRune;
using UE.Engine;

namespace ModLabLoaderProbe;

// Never distributed or installed for normal play. Two packages built from the
// same class name verify discovery and duplicate detection by class identity.
public class ModActor : AActor
{
    protected override void ReceiveBeginPlay()
    {
        var instances = World.FindAll(this, Unreal.ClassOf<ModActor>());
        if (UKismetSystemLibrary.GetCommandLine().Contains("-ModLabLoaderDiagnostics"))
            Log.Write($"[ModLab Loader] probe {Unreal.ModName}; level={World.LevelName(this)}; instances={instances.Count}");
    }
}
