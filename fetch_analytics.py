#!/usr/bin/env python3
"""
Firebase Analytics Insights Fetcher for HealthPulse (laso-health-v1)

Fetches all key analytics data from your Firebase/GA4 property to verify
that analytics tracking is working correctly.

Setup:
  1. Go to Firebase Console > Project Settings > Service Accounts
  2. Click "Generate New Private Key" and save the JSON file
  3. Go to Google Analytics (analytics.google.com) > Admin > Property Settings
     to find your GA4 Property ID (numeric, e.g. 123456789)
  4. Make sure the service account email has "Viewer" role in GA4:
     Google Analytics > Admin > Property Access Management > Add the service account email

Usage:
  pip install google-analytics-data google-auth
  python fetch_analytics.py --property-id YOUR_GA4_PROPERTY_ID --credentials path/to/service-account.json
"""

import argparse
import json
import sys
from datetime import datetime, timedelta

try:
    from google.analytics.data_v1beta import BetaAnalyticsDataClient
    from google.analytics.data_v1beta.types import (
        DateRange,
        Dimension,
        Filter,
        FilterExpression,
        Metric,
        OrderBy,
        RunRealtimeReportRequest,
        RunReportRequest,
    )
    from google.oauth2 import service_account
except ImportError:
    print("Missing dependencies. Install them with:")
    print("  pip install google-analytics-data google-auth")
    sys.exit(1)


def create_client(credentials_path: str) -> BetaAnalyticsDataClient:
    """Create an authenticated GA4 Data API client."""
    credentials = service_account.Credentials.from_service_account_file(
        credentials_path,
        scopes=["https://www.googleapis.com/auth/analytics.readonly"],
    )
    return BetaAnalyticsDataClient(credentials=credentials)


def print_section(title: str):
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")


def print_table(headers: list[str], rows: list[list[str]]):
    """Print a simple aligned table."""
    if not rows:
        print("  (no data)")
        return
    col_widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            col_widths[i] = max(col_widths[i], len(str(cell)))
    fmt = "  ".join(f"{{:<{w}}}" for w in col_widths)
    print(f"  {fmt.format(*headers)}")
    print(f"  {'-' * sum(col_widths + [2 * (len(col_widths) - 1)])}")
    for row in rows:
        print(f"  {fmt.format(*[str(c) for c in row])}")


def run_report(client, property_id, dimensions, metrics, date_range_days=30,
               order_by_metric=None, limit=20, dimension_filter=None):
    """Run a GA4 report and return rows as list of dicts."""
    request = RunReportRequest(
        property=f"properties/{property_id}",
        dimensions=[Dimension(name=d) for d in dimensions],
        metrics=[Metric(name=m) for m in metrics],
        date_ranges=[DateRange(
            start_date=f"{date_range_days}daysAgo",
            end_date="today",
        )],
        limit=limit,
    )
    if order_by_metric:
        request.order_bys = [OrderBy(
            metric=OrderBy.MetricOrderBy(metric_name=order_by_metric),
            desc=True,
        )]
    if dimension_filter:
        request.dimension_filter = dimension_filter

    response = client.run_report(request)
    rows = []
    for row in response.rows:
        entry = {}
        for i, dim in enumerate(dimensions):
            entry[dim] = row.dimension_values[i].value
        for i, met in enumerate(metrics):
            entry[met] = row.metric_values[i].value
        rows.append(entry)
    return rows


# ── Report Functions ─────────────────────────────────────────

def report_overview(client, pid):
    """High-level overview: users, sessions, events."""
    print_section("OVERVIEW (Last 30 Days)")
    rows = run_report(client, pid,
                      dimensions=[],
                      metrics=[
                          "activeUsers",
                          "newUsers",
                          "sessions",
                          "eventCount",
                          "screenPageViews",
                          "averageSessionDuration",
                          "engagedSessions",
                      ])
    if rows:
        r = rows[0]
        print(f"  Active Users:             {r.get('activeUsers', 'N/A')}")
        print(f"  New Users:                {r.get('newUsers', 'N/A')}")
        print(f"  Sessions:                 {r.get('sessions', 'N/A')}")
        print(f"  Engaged Sessions:         {r.get('engagedSessions', 'N/A')}")
        print(f"  Total Events:             {r.get('eventCount', 'N/A')}")
        print(f"  Screen/Page Views:        {r.get('screenPageViews', 'N/A')}")
        dur = float(r.get('averageSessionDuration', 0))
        print(f"  Avg Session Duration:     {dur:.1f}s ({dur/60:.1f} min)")
    else:
        print("  (no data — analytics may not be receiving events yet)")


def report_daily_active_users(client, pid):
    """Daily active users for the last 30 days."""
    print_section("DAILY ACTIVE USERS (Last 30 Days)")
    rows = run_report(client, pid,
                      dimensions=["date"],
                      metrics=["activeUsers", "newUsers", "eventCount"],
                      date_range_days=30, limit=30)
    rows.sort(key=lambda r: r["date"])
    table_rows = []
    for r in rows:
        d = r["date"]
        formatted = f"{d[:4]}-{d[4:6]}-{d[6:]}"
        table_rows.append([formatted, r["activeUsers"], r["newUsers"], r["eventCount"]])
    print_table(["Date", "Active Users", "New Users", "Events"], table_rows)


def report_events(client, pid):
    """Top events by count."""
    print_section("TOP EVENTS (Last 30 Days)")
    rows = run_report(client, pid,
                      dimensions=["eventName"],
                      metrics=["eventCount", "totalUsers"],
                      order_by_metric="eventCount", limit=30)
    table_rows = [[r["eventName"], r["eventCount"], r["totalUsers"]] for r in rows]
    print_table(["Event Name", "Count", "Users"], table_rows)


def report_screens(client, pid):
    """Top screens/pages viewed."""
    print_section("TOP SCREENS (Last 30 Days)")
    rows = run_report(client, pid,
                      dimensions=["unifiedScreenName"],
                      metrics=["screenPageViews", "totalUsers"],
                      order_by_metric="screenPageViews", limit=20)
    table_rows = [[r["unifiedScreenName"], r["screenPageViews"], r["totalUsers"]] for r in rows]
    print_table(["Screen Name", "Views", "Users"], table_rows)


def report_user_demographics(client, pid):
    """User platform, OS, device info."""
    print_section("PLATFORMS & DEVICES (Last 30 Days)")

    # Platform
    print("\n  [Platform]")
    rows = run_report(client, pid,
                      dimensions=["platform"],
                      metrics=["activeUsers"],
                      order_by_metric="activeUsers")
    print_table(["Platform", "Users"], [[r["platform"], r["activeUsers"]] for r in rows])

    # OS Version
    print("\n  [OS Version]")
    rows = run_report(client, pid,
                      dimensions=["operatingSystemVersion"],
                      metrics=["activeUsers"],
                      order_by_metric="activeUsers", limit=10)
    print_table(["OS Version", "Users"],
                [[r["operatingSystemVersion"], r["activeUsers"]] for r in rows])

    # Device Model
    print("\n  [Device Model]")
    rows = run_report(client, pid,
                      dimensions=["mobileDeviceModel"],
                      metrics=["activeUsers"],
                      order_by_metric="activeUsers", limit=10)
    print_table(["Device Model", "Users"],
                [[r["mobileDeviceModel"], r["activeUsers"]] for r in rows])

    # App Version
    print("\n  [App Version]")
    rows = run_report(client, pid,
                      dimensions=["appVersion"],
                      metrics=["activeUsers"],
                      order_by_metric="activeUsers", limit=10)
    print_table(["App Version", "Users"],
                [[r["appVersion"], r["activeUsers"]] for r in rows])


def report_geography(client, pid):
    """User geography: country and city."""
    print_section("USER GEOGRAPHY (Last 30 Days)")

    print("\n  [Country]")
    rows = run_report(client, pid,
                      dimensions=["country"],
                      metrics=["activeUsers"],
                      order_by_metric="activeUsers", limit=10)
    print_table(["Country", "Users"], [[r["country"], r["activeUsers"]] for r in rows])

    print("\n  [City]")
    rows = run_report(client, pid,
                      dimensions=["city"],
                      metrics=["activeUsers"],
                      order_by_metric="activeUsers", limit=10)
    print_table(["City", "Users"], [[r["city"], r["activeUsers"]] for r in rows])


def report_user_engagement(client, pid):
    """Engagement metrics: retention, session duration distribution."""
    print_section("USER ENGAGEMENT (Last 30 Days)")

    # By session source
    print("\n  [Traffic Source]")
    rows = run_report(client, pid,
                      dimensions=["sessionSource"],
                      metrics=["sessions", "engagedSessions", "activeUsers"],
                      order_by_metric="sessions", limit=10)
    table_rows = [[r["sessionSource"], r["sessions"], r["engagedSessions"], r["activeUsers"]]
                  for r in rows]
    print_table(["Source", "Sessions", "Engaged Sessions", "Users"], table_rows)

    # First user source (acquisition)
    print("\n  [User Acquisition Source]")
    rows = run_report(client, pid,
                      dimensions=["firstUserSource"],
                      metrics=["newUsers", "activeUsers"],
                      order_by_metric="newUsers", limit=10)
    table_rows = [[r["firstUserSource"], r["newUsers"], r["activeUsers"]] for r in rows]
    print_table(["First Source", "New Users", "Active Users"], table_rows)


def report_custom_events(client, pid):
    """Show events that are NOT default GA4 auto-collected events."""
    print_section("CUSTOM / NON-DEFAULT EVENTS (Last 30 Days)")
    auto_events = {
        "first_visit", "session_start", "user_engagement",
        "screen_view", "page_view", "scroll", "click",
        "view_search_results", "file_download", "video_start",
        "video_progress", "video_complete", "first_open",
        "app_remove", "app_update", "os_update",
        "ad_impression", "ad_click", "ad_query", "ad_exposure",
    }
    rows = run_report(client, pid,
                      dimensions=["eventName"],
                      metrics=["eventCount", "totalUsers"],
                      order_by_metric="eventCount", limit=50)
    custom_rows = [[r["eventName"], r["eventCount"], r["totalUsers"]]
                   for r in rows if r["eventName"] not in auto_events]
    if custom_rows:
        print_table(["Event Name", "Count", "Users"], custom_rows)
    else:
        print("  No custom events found. Only auto-collected events are being logged.")
        print("  If you expect custom events, verify your logEvent() calls in the app.")


def report_realtime(client, pid):
    """Realtime active users (last 30 minutes)."""
    print_section("REALTIME (Last 30 Minutes)")
    try:
        request = RunRealtimeReportRequest(
            property=f"properties/{pid}",
            dimensions=[Dimension(name="unifiedScreenName")],
            metrics=[Metric(name="activeUsers")],
        )
        response = client.run_realtime_report(request)
        total = 0
        table_rows = []
        for row in response.rows:
            screen = row.dimension_values[0].value
            users = row.metric_values[0].value
            total += int(users)
            table_rows.append([screen, users])
        print(f"  Total active users right now: {total}")
        if table_rows:
            print()
            print_table(["Screen", "Active Users"], table_rows)
    except Exception as e:
        print(f"  Could not fetch realtime data: {e}")


def report_event_params(client, pid):
    """Show event parameters for key custom events (if any)."""
    print_section("EVENT PARAMETERS SAMPLE (Last 7 Days)")
    # Get top 5 events first
    rows = run_report(client, pid,
                      dimensions=["eventName"],
                      metrics=["eventCount"],
                      order_by_metric="eventCount", limit=10,
                      date_range_days=7)
    auto_events = {
        "first_visit", "session_start", "user_engagement",
        "screen_view", "page_view", "first_open",
    }
    custom = [r["eventName"] for r in rows if r["eventName"] not in auto_events][:5]
    if not custom:
        print("  No non-default events to inspect parameters for.")
        return

    for event_name in custom:
        print(f"\n  Event: {event_name}")
        try:
            dim_filter = FilterExpression(
                filter=Filter(
                    field_name="eventName",
                    string_filter=Filter.StringFilter(value=event_name),
                )
            )
            params_rows = run_report(
                client, pid,
                dimensions=["customEvent:parameter_name"] if False else ["eventName"],
                metrics=["eventCount"],
                date_range_days=7,
                dimension_filter=dim_filter,
                limit=5,
            )
            # Try with screen context
            context_rows = run_report(
                client, pid,
                dimensions=["eventName", "unifiedScreenName"],
                metrics=["eventCount"],
                date_range_days=7,
                dimension_filter=dim_filter,
                order_by_metric="eventCount",
                limit=5,
            )
            if context_rows:
                table_rows = [[r["unifiedScreenName"], r["eventCount"]] for r in context_rows]
                print_table(["Screen", "Count"], table_rows)
            else:
                print("    (no screen context data)")
        except Exception as e:
            print(f"    Could not fetch details: {e}")


# ── Main ─────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Fetch Firebase Analytics insights for HealthPulse (laso-health-v1)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
How to find your GA4 Property ID:
  1. Go to https://analytics.google.com
  2. Admin (gear icon) > Property Settings
  3. The Property ID is the numeric ID at the top (e.g. 123456789)

  OR in Firebase Console:
  1. Project Settings > Integrations > Google Analytics
  2. The linked GA4 property ID is shown there
        """,
    )
    parser.add_argument("--property-id", required=True,
                        help="GA4 Property ID (numeric, e.g. 123456789)")
    parser.add_argument("--credentials", required=True,
                        help="Path to service account JSON key file")
    parser.add_argument("--report", default="all",
                        choices=["all", "overview", "daily", "events", "screens",
                                 "devices", "geography", "engagement", "custom",
                                 "realtime", "params"],
                        help="Which report to run (default: all)")
    args = parser.parse_args()

    print(f"\nFirebase Analytics Insights — HealthPulse (laso-health-v1)")
    print(f"GA4 Property: {args.property_id}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    client = create_client(args.credentials)

    reports = {
        "overview": report_overview,
        "daily": report_daily_active_users,
        "events": report_events,
        "screens": report_screens,
        "devices": report_user_demographics,
        "geography": report_geography,
        "engagement": report_user_engagement,
        "custom": report_custom_events,
        "realtime": report_realtime,
        "params": report_event_params,
    }

    if args.report == "all":
        for name, fn in reports.items():
            try:
                fn(client, args.property_id)
            except Exception as e:
                print(f"\n  [ERROR in {name}] {e}")
    else:
        reports[args.report](client, args.property_id)

    print(f"\n{'=' * 60}")
    print("  Done! If all sections show (no data), check:")
    print("  1. Analytics is enabled in Firebase Console")
    print("  2. Your app has been opened at least once")
    print("  3. The service account has Viewer access in GA4")
    print("  4. Wait 24-48h for data to populate (realtime is instant)")
    print(f"{'=' * 60}\n")


if __name__ == "__main__":
    main()
