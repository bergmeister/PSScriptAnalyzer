using System;
using System.Runtime.Serialization;

namespace Microsoft.PowerShell.CrossCompatibility.Data.Types
{
    /// <summary>
    /// Describes a property on a .NET type.
    /// </summary>
    [Serializable]
    [DataContract]
    public class PropertyData : ICloneable
    {
        /// <summary>
        /// Lists the accessors available on this property.
        /// </summary>
        [DataMember]
        public AccessorType[] Accessors { get; set; }

        /// <summary>
        /// The full name of the type of the property.
        /// </summary>
        [DataMember]
        public string Type { get; set; }

        public object Clone()
        {
            return new PropertyData()
            {
                Accessors = (AccessorType[])Accessors.Clone(),
                Type = Type
            };
        }
    }
}