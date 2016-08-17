namespace GeekLearning.VstsTasks.Azure.Tests
{
    using Xunit;

    [CollectionDefinition(nameof(UnitTestsCollection))]
    public class UnitTestsCollection : ICollectionFixture<ConfigurationFixture>
    {
    }
}
