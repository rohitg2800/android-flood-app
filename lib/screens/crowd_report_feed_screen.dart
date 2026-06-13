// lib/screens/crowd_report_feed_screen.dart
// OpsFlood — Module 14: Crowd-Report Feed
//
// Citizens can:
//  • Post a flood incident (photo, location, type, severity)
//  • View a live feed of verified + unverified reports
//  • Upvote/flag reports
//  • Filter by district or type
//  • Reports stored in Firestore: crowd_reports/{docId}

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme/river_theme.dart';
