using System.Text.Json.Serialization;

namespace AlbumFrontEndWeb.Pages;

public class Album
{
    [JsonPropertyName("id")] public int Id { get; set; }
    [JsonPropertyName("title")] public string Title { get; set; } = default!;
    [JsonPropertyName("artist")] public string Artist { get; set; } = default!;
    [JsonPropertyName("price")] public decimal Price { get; set; } = default!;
    
    [JsonPropertyName("image_url")] public string ImageUrl { get; set; } = default!;
}