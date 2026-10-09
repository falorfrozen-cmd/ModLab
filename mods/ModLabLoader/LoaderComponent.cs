using NeoRune;
using UE.Engine;

namespace ModLabLoader;

/// <summary>The engine adds this non-ticking component when a local controller starts.</summary>
public class LoaderComponent : UActorComponent
{
    public override void ReceiveBeginPlay()
    {
        var controller = GetOwner() as APlayerController;
        if (controller == null || !controller.IsLocalController()) return;
        if (UGameplayStatics.GetPlayerController(this, 0) != controller) return;
        var existing = World.FindAll(this, Unreal.ClassOf<ModActor>());
        if (existing.Count != 0) return;
        World.Spawn(this, Unreal.ClassOf<ModActor>(), new UE.CoreUObject.FVector());
    }
}
