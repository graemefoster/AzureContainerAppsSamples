using System.Text.Json;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace AlbumFrontEndWeb.Pages;

public class AlbumsModel : PageModel
{
    private readonly ILogger<IndexModel> _logger;
    private readonly IHttpClientFactory _httpClientFactory;

    public AlbumsModel(ILogger<IndexModel> logger, IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClientFactory = httpClientFactory;
    }

    public async Task OnGetAsync()
    {
        _logger.LogInformation("Fetching Albums from Spring Microservice");
        var client = _httpClientFactory.CreateClient();
        var albums = await client.GetStringAsync("http://backend/albums");
        Albums = JsonSerializer.Deserialize<Album[]>(albums);
    }

    public Album[]? Albums { get; set; }
}