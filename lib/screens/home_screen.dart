import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/course.dart';
import '../services/auth_service.dart';
import '../services/course_service.dart';
import '../services/download_service.dart';
import '../services/lesson_video_controller.dart';
import '../widgets/catalog_message.dart';
import '../widgets/course_card.dart';
import 'course_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.onLoggedOut,
    this.courseService,
    required this.downloadService,
    this.videoControllerFactory,
  });

  final AuthUser user;
  final VoidCallback onLoggedOut;
  final CourseService? courseService;
  final DownloadService downloadService;
  final LessonVideoControllerFactory? videoControllerFactory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  late final CourseService _courseService;
  late Future<List<Course>> _coursesFuture;
  String _searchQuery = '';
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _courseService = widget.courseService ?? CourseService();
    _coursesFuture = _courseService.loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      await _authService.logout();
    } finally {
      if (mounted) {
        widget.onLoggedOut();
      }
    }
  }

  void _retryLoadingCourses() {
    setState(() {
      _coursesFuture = _courseService.loadCourses();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  List<Course> _filterCourses(List<Course> courses) {
    final String query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return courses;
    }

    return courses.where((Course course) {
      return course.title.toLowerCase().contains(query) ||
          course.category.toLowerCase().contains(query) ||
          course.instructor.toLowerCase().contains(query);
    }).toList();
  }

  void _openCourse(Course course) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return CourseDetailsScreen(
            course: course,
            downloadService: widget.downloadService,
            videoControllerFactory: widget.videoControllerFactory,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini E-Learning'),
        actions: [
          IconButton(
            key: const Key('homeLogoutButton'),
            tooltip: 'Log out',
            onPressed: _isLoggingOut ? null : _logout,
            icon: _isLoggingOut
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Course>>(
          future: _coursesFuture,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<Course>> snapshot,
          ) {
            final bool isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final List<Course> allCourses =
                snapshot.data ?? const <Course>[];
            final List<Course> visibleCourses = _filterCourses(allCourses);
            final Object? error = snapshot.error;

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int crossAxisCount = constraints.maxWidth >= 1080
                    ? 3
                    : constraints.maxWidth >= 680
                    ? 2
                    : 1;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _WelcomeHeader(user: widget.user),
                          const SizedBox(height: 28),
                          _CatalogHeading(
                            courseCount: isLoading ? null : allCourses.length,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('courseSearchField'),
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onChanged: (String value) {
                              setState(() => _searchQuery = value);
                            },
                            decoration: InputDecoration(
                              hintText:
                                  'Search by title, category, or instructor',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: _clearSearch,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (isLoading)
                            const _LoadingState()
                          else if (error != null)
                            CatalogMessage(
                              icon: Icons.cloud_off_rounded,
                              title: 'Could not load courses',
                              message: error is CourseLoadException
                                  ? error.message
                                  : 'Something went wrong while loading the '
                                        'course catalog.',
                              action: FilledButton.icon(
                                key: const Key('courseRetryButton'),
                                onPressed: _retryLoadingCourses,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try again'),
                              ),
                            )
                          else if (visibleCourses.isEmpty)
                            CatalogMessage(
                              icon: Icons.search_off_rounded,
                              title: 'No courses found',
                              message:
                                  'No courses match "${_searchQuery.trim()}". '
                                  'Try a different title, category, or '
                                  'instructor.',
                              action: TextButton(
                                onPressed: _clearSearch,
                                child: const Text('Clear search'),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: visibleCourses.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    mainAxisExtent: 460,
                                  ),
                              itemBuilder: (BuildContext context, int index) {
                                final Course course = visibleCourses[index];
                                return CourseCard(
                                  key: Key('courseCard-${course.id}'),
                                  course: course,
                                  onTap: () => _openCourse(course),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String firstLetter = user.name.isNotEmpty
        ? user.name.characters.first.toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              firstLetter,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogHeading extends StatelessWidget {
  const _CatalogHeading({required this.courseCount});

  final int? courseCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore courses',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a course and keep building your skills.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (courseCount != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$courseCount ${courseCount == 1 ? 'course' : 'courses'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading courses...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
