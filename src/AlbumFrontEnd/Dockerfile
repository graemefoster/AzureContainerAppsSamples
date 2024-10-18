# Use the official .NET 8 SDK image as a build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

# Set the working directory
WORKDIR /src

# Copy the project file and restore dependencies
COPY AlbumFrontEndWeb/*.csproj ./AlbumFrontEndWeb/
RUN dotnet restore ./AlbumFrontEndWeb/AlbumFrontEndWeb.csproj

# Copy the rest of the application code
COPY AlbumFrontEndWeb/. ./AlbumFrontEndWeb/

# Build the application
RUN dotnet publish ./AlbumFrontEndWeb/AlbumFrontEndWeb.csproj -c Release -o /app/publish

# Use the official .NET runtime image as a runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime

# Set the working directory
WORKDIR /app

# Copy the published application from the build stage
COPY --from=build /app/publish .

# Expose the port the app runs on
EXPOSE 8080

# Set the entry point for the application
ENTRYPOINT ["dotnet", "AlbumFrontEndWeb.dll"]
