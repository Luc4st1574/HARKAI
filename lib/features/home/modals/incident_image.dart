import 'package:flutter/material.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import
import 'package:harkai/features/home/utils/extensions.dart';

class IncidentImageDisplayModal extends StatelessWidget {
  final IncidenceData incidence;

  const IncidentImageDisplayModal({super.key, required this.incidence});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; // Get localizations

    // getMarkerInfo now requires localizations
    final MarkerInfo? markerDetails = getMarkerInfo(incidence.type, localizations); 
    final Color accentColor = markerDetails?.color ?? Colors.blueGrey;
    
    // Title comes from localized markerDetails
    final String title = markerDetails?.title ?? incidence.type.name.toString().split('.').last.capitalizeAllWords();

    return Dialog(
      backgroundColor: const Color(0xFF001F3F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: accentColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title, // Already localized
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 15),

            if (incidence.description.isNotEmpty)
              Text(
                localizations.incidentImageModalDescriptionLabel, // Localized
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withAlpha((0.9 * 255).toInt()),
                ),
              ),
            if (incidence.description.isNotEmpty) const SizedBox(height: 5),
            if (incidence.description.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  incidence.description, // This is data
                  style: TextStyle(fontSize: 15, color: Colors.white.withAlpha((0.85 * 255).toInt())),
                ),
              ),
            const SizedBox(height: 15),
            if (incidence.imageUrl != null)
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withAlpha((0.5 * 255).toInt()))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    incidence.imageUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                      // ... (loading builder remains the same)
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
                        height: 150,
                        color: Colors.grey[800],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 50, color: accentColor.withAlpha((0.7 * 255).toInt())),
                              const SizedBox(height: 8),
                              Text(localizations.incidentImageModalImageUnavailable, style: TextStyle(color: Colors.white70)), // Localized
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              SizedBox(
                height: 100,
                child: Center(child: Text(localizations.incidentImageModalNoImage, style: TextStyle(color: Colors.white70))), // Localized
              ),

            if (incidence.description.isEmpty && incidence.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  localizations.incidentImageModalNoAdditionalDescription, // Localized
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withAlpha((0.7 * 255).toInt())),
                ),
              ),
            
            const SizedBox(height: 25),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.incidentImageModalCloseButton, style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold)), // Localized
            ),
          ],
        ),
      ),
    );
  }
}