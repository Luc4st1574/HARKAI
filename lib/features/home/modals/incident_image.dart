import 'package:flutter/material.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart'; // For MarkerInfo and getMarkerInfo

class IncidentImageDisplayModal extends StatelessWidget {
  final IncidenceData incidence;

  const IncidentImageDisplayModal({super.key, required this.incidence});

  @override
  Widget build(BuildContext context) {
    final MarkerInfo? markerDetails = getMarkerInfo(incidence.type);
    final Color accentColor = markerDetails?.color ?? Colors.blueGrey;
    // Use capitalizeAllWords from the StringExtension you defined earlier
    final String title = markerDetails?.title ?? incidence.type.name.toString().split('.').last.capitalizeAllWords();

    return Dialog(
      backgroundColor: const Color(0xFF001F3F), // Dark background from your theme
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: accentColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Important to make the dialog wrap content
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 15),

            // Description Display
            if (incidence.description.isNotEmpty)
              Text(
                "Description:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            if (incidence.description.isNotEmpty) const SizedBox(height: 5),
            if (incidence.description.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2), // Subtle background for description
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  incidence.description,
                  style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.85)),
                ),
              ),
            // Message if only image exists and no description (moved to be after potential image)
            // We will handle the "No additional description provided." message differently below if needed.

            const SizedBox(height: 15), // Spacing between description and image

            // Image Display
            if (incidence.imageUrl != null)
              Container(
                constraints: BoxConstraints(
                  // Max height to prevent dialog from becoming too tall
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withOpacity(0.5))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    incidence.imageUrl!,
                    fit: BoxFit.contain, // Use contain to see the whole image
                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150, // Placeholder height
                        color: Colors.grey[800],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 50, color: accentColor.withOpacity(0.7)),
                              const SizedBox(height: 8),
                              Text("Image unavailable", style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            else // Placeholder if no image
              Container(
                height: 100, // Adjusted height if needed, or remove if "No image" is not desired here
                child: Center(child: Text("No image for this incident.", style: TextStyle(color: Colors.white70))),
              ),

            // Message if description is empty AND an image exists
            // This replaces the previous "No additional description provided." logic to fit the new order
            if (incidence.description.isEmpty && incidence.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0), // Add some space above this text if needed
                child: Text(
                  "No additional description provided for the image.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ),
            
            const SizedBox(height: 25),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}