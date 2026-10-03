using Xunit;

namespace DM_Helper.Core.Tests;

/// <summary>
/// Timing-sensitive tests must not run alongside other tests.
///
/// <see cref="DM_Helper.Core.Engine.PreciseTimer"/> spins rather than sleeping for its
/// final few milliseconds. Several of those threads competing for a CPU with the rest of the
/// suite starves each other, which is how the first version of these tests passed locally
/// and failed on a CI runner.
/// </summary>
[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class SerialCollection
{
    public const string Name = "TimingSensitive";
}
