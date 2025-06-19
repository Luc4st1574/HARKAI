import 'dart:async';
import 'dart:io'; // For File operations

import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:harkai/core/services/storage_service.dart';
import 'package:harkai/core/services/speech_service.dart';

class IncidentMediaServices {
  final String _apiKey;
  final SpeechPermissionService _speechPermissionService;

  IncidentMediaServices({required String apiKey})
      : _apiKey = apiKey,
        _speechPermissionService = SpeechPermissionService();

  // --- Permission Service ---

  /// Checks the current status of the microphone permission.
  Future<PermissionStatus> getMicrophonePermissionStatus() async {
    return await Permission.microphone.status;
  }

  /// Requests microphone permission.
  Future<bool> requestMicrophonePermission(
      {bool openSettingsOnError = true}) async {
    return await _speechPermissionService.requestMicrophonePermission(
        openSettingsOnError: openSettingsOnError);
  }

  // --- Gemini Service ---

  /// Initializes the GenerativeModel for Gemini.
  GenerativeModel? initializeGeminiModel() {
    if (_apiKey.isEmpty) {
      debugPrint(
          "IncidentMediaServices: Gemini API Key (HARKI_KEY) not found or empty.");
      return null;
    }
    // This system instruction is taken directly from your original code.
    const systemInstructionText =
        "You are Harki, an AI assistant for the Harkai citizen security app. "
        "Analyze user-provided media (audio or image) based on their specific instructions which will include a pre-selected incident type. "
        "Provide concise responses in the specified formats (MATCH, MISMATCH, INAPPROPRIATE, UNCLEAR). "
        "Prioritize safety and relevance. Respond in the language of the input if identifiable (Spanish/English), else English."
        "Most user inputs will be in Spanish, so prioritize that language unless specified otherwise and do not translate your response to english if spanish was the used languaje by the user.";

    try {
      return GenerativeModel(
        model: 'gemini-1.5-flash', // Consider making model name configurable if needed
        apiKey: _apiKey,
        systemInstruction: Content.system(systemInstructionText),
        generationConfig:
            GenerationConfig(temperature: 0.7, maxOutputTokens: 150),
      );
    } catch (e) {
      debugPrint(
          "IncidentMediaServices: Failed to initialize Gemini model: ${e.toString()}");
      return null;
    }
  }

  /// Sends audio data to the Gemini model for analysis.
  Future<String?> analyzeAudioWithGemini({
    required GenerativeModel model,
    required Uint8List audioBytes,
    required String audioMimeType,
    required String incidentTypeName, // Expects already capitalized name
  }) async {
    // This user instruction for audio is taken directly from your original code.
    final audioUserInstruction =
        "Incident Type: '$incidentTypeName'. Process the following audio. "
        "On the theft incident type, this includes all kinds of theft, robbery, or burglary. even car theft and armed robbery all kinds of theft, robbery, or burglary please be conscious of this and if it as a theft incident do always a good check. "
        "On the crash incident type, this includes all kinds of car accidents, motorcycle accidents, and pedestrian accidents. "
        "On the fire incident type, this includes all kinds of fires, explosions, or smoke. "
        "On the places incident type, this is for addding businesses, stores and so to the mpap, this is not for incidents but for adding places to the map so be conscious of this and do not use it for incidents, here just add what the user tells you do not try to give it more context or description cause it will look weird, just repeat what the user says on this kind incident do not add anything else. "
        "On the emergency incident type, this includes all kinds of emergencies, like medical emergencies, natural disasters, or other urgent situations, lesions and all related this is a incident type that must be open to a lot of posible thing so be conscius of all kind of possible emergencies. "
        "Expected response formats: 'MATCH: [Short summary, max 15 words, of the audio content related to the incident type.]', "
        "'MISMATCH: This audio seems to describe a [Correct Incident Type] incident. Please confirm this type or re-record for the $incidentTypeName incident.', "
        "'UNCLEAR: The audio was not clear enough or did not describe a reportable incident for '$incidentTypeName'. Please try recording again with more details.'"
        "If the user give a instruction in Spanish you must respond in Spanish except the part of 'MATCH', 'MISMATCH' or 'UNCLEAR' that must be in English."
        "Only the part of 'MATCH', 'MISMATCH' or 'UNCLEAR' must be in English, the rest of the response must be in Spanish do not omit this part at all cost do not omit it please."
        "Do not translate the response to English if Spanish was the used language by the user.";

    try {
      final response = await model.generateContent([
        Content('user', [
          TextPart(audioUserInstruction),
          DataPart(audioMimeType, audioBytes),
        ])
      ]);
      return response.text;
    } catch (e) {
      debugPrint(
          "IncidentMediaServices: Gemini audio processing failed: ${e.toString()}");
      return null;
    }
  }

  Future<String?> analyzeTextWithGemini({
    required GenerativeModel model,
    required String text,
    required String incidentTypeName,
  }) async {
    final textUserInstruction =
      "Incident Type: '$incidentTypeName'. Process the following text. "
      "On the theft incident type, this includes all kinds of theft, robbery, or burglary. even car theft and armed robbery all kinds of theft, robbery, or burglary please be conscious of this and if it as a theft incident do always a good check. "
      "On the crash incident type, this includes all kinds of car accidents, motorcycle accidents, and pedestrian accidents. "
      "On the fire incident type, this includes all kinds of fires, explosions, or smoke. "
      "On the places incident type, this is for addding businesses, stores and so to the mpap, this is not for incidents but for adding places to the map so be conscious of this and do not use it for incidents, here just add what the user tells you do not try to give it more context or description cause it will look weird, just repeat what the user says on this kind incident do not add anything else. "
      "On the emergency incident type, this includes all kinds of emergencies, like medical emergencies, natural disasters, or other urgent situations, lesions and all related this is a incident type that must be open to a lot of posible thing so be conscius of all kind of possible emergencies. "
      "Expected response formats: 'MATCH: [Short summary, max 15 words, of the text content related to the incident type.]', "
      "'MISMATCH: This text seems to describe a [Correct Incident Type] incident. Please confirm this type or re-enter for the $incidentTypeName incident.', "
      "'UNCLEAR: The text was not clear enough or did not describe a reportable incident for '$incidentTypeName'. Please try entering again with more details.'"
      "If the user give a instruction in Spanish you must respond in Spanish except the part of 'MATCH', 'MISMATCH' or 'UNCLEAR' that must be in English."
      "Only the part of 'MATCH', 'MISMATCH' or 'UNCLEAR' must be in English, the rest of the response must be in Spanish do not omit this part at all cost do not omit it please."
      "Do not translate the response to English if Spanish was the used language by the user.";
  try {
    if (text.isEmpty) {
      debugPrint("IncidentMediaServices: Text input is empty.");
      return null;
    }
    final response = await model.generateContent([
      Content('user', [
      TextPart(textUserInstruction),
      TextPart(text),
      ])
    ]);
  return response.text;
  } catch (e) {
    debugPrint("IncidentMediaServices: Gemini text processing failed: ${e.toString()}");
    return null;
    }
  }


  /// Sends image data to the Gemini model for analysis.
  Future<String?> analyzeImageWithGemini({
    required GenerativeModel model,
    required Uint8List imageBytes,
    required String imageMimeType,
    required String incidentTypeName, // Expects already capitalized name
  }) async {
    // This user instruction for image is taken directly from your original code.
    final imageUserInstruction =
        "Incident Type: '$incidentTypeName'. Process the following image. "
        "1. SAFETY: If image contains explicit sexual content or excessive gore, respond EXACTLY with 'INAPPROPRIATE: The image contains content that cannot be posted.'. "
        "2. RELEVANCE (If safe): Does image genuinely match '$incidentTypeName'? "
        "3. RESPONSE (If safe): "
        "IF MATCHES INCIDENT TYPE: Respond EXACTLY 'MATCH:'. "
        "IF MISMATCH (but valid other type like Fire, Crash, Theft, Pet, Emergency): Respond EXACTLY 'MISMATCH: This image looks more like a [Correct Incident Type] alert. Please confirm this type or retake image for $incidentTypeName incident.'. "
        "IF IRRELEVANT/UNCLEAR: Respond EXACTLY 'UNCLEAR: The image is not clear enough or does not seem to describe a reportable incident for '$incidentTypeName'. Please try retaking the picture.'."
        "The places incident type is for adding businesses, stores,parks,plazas,malls and so on to the map, this is not for incidents but for adding places to the map so be conscious of this and do not use it for incidents. "
        "If the user give a instruction in Spanish you must respond in Spanish except the part of 'MATCH', 'MISMATCH' or 'IRRELEVANT/UNCLEAR' that must be in English."
        "Only the part of 'MATCH', 'MISMATCH' or 'IRRELEVANT/UNCLEAR' must be in English, the rest of the response must be in Spanish do not omit this part at all cost do not omit it please."
        "Do not translate the response to English if Spanish was the used language by the user.";

    try {
      final response = await model.generateContent([
        Content('user', [
          TextPart(imageUserInstruction),
          DataPart(imageMimeType, imageBytes),
        ])
      ]);
      return response.text;
    } catch (e) {
      debugPrint(
          "IncidentMediaServices: Gemini image processing failed: ${e.toString()}");
      return null;
    }
  }

  // --- Storage Service ---
  Future<String?> uploadIncidentImage({
    required StorageService storageService,
    required File imageFile,
    required String userId,
    required String incidentType,
  }) async {
    try {
      return await storageService.uploadIncidentImage(
        imageFile: imageFile,
        userId: userId,
        incidentType: incidentType,
      );
    } catch (e) {
      debugPrint(
          "IncidentMediaServices: Failed to upload image via StorageService: ${e.toString()}");
      return null;
    }
  }
}