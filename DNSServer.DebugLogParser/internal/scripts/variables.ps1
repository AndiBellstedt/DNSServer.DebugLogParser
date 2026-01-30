# Module-wide variables go here
# For example if you want to cache some data, have some module-wide config settings, etc. ... those could go here
# Example:
# $script:config = @{ }

#region Async Processing Support Detection
# Check if System.Collections.Concurrent types are available for async producer-consumer processing
# These types are available in .NET Framework 4.0+ (PS 5.1) and .NET Core (PS 7+)
# If types are not available, the module will fall back to synchronous processing

$script:AsyncSupported = $false

try {
    # Test BlockingCollection availability (core type for producer-consumer pattern)
    $null = [System.Collections.Concurrent.BlockingCollection[string]]

    # Test ConcurrentDictionary availability (for thread-safe statistics)
    $null = [System.Collections.Concurrent.ConcurrentDictionary[string, int]]

    # Test ConcurrentQueue availability (for error/message queues)
    $null = [System.Collections.Concurrent.ConcurrentQueue[string]]

    # All required types are available
    $script:AsyncSupported = $true
} catch {
    # Types not available - async processing will be disabled
    $script:AsyncSupported = $false
}

# Pre-create the increment delegate for ConcurrentDictionary.AddOrUpdate (performance optimization)
# This delegate is used for thread-safe counter increments in statistics collection
# Creating it once avoids repeated delegate allocation overhead in hot paths
if ($script:AsyncSupported) {
    $script:IncrementFunc = [Func[string, int, int]] { param($key, $existingValue) $existingValue + 1 }
}
#endregion Async Processing Support Detection