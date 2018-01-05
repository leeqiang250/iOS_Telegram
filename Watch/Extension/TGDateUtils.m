#import "TGDateUtils.h"
#import "TGStringUtils.h"
#import <time.h>

static bool value_dateHas12hFormat = false;
static __strong NSString *value_monthNamesGenShort[] = {
    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
};
static __strong NSString *value_monthNamesGenFull[] = {
    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
};
static __strong NSString *value_weekdayNamesShort[] = {
    nil, nil, nil, nil, nil, nil, nil
};
static __strong NSString *value_weekdayNamesFull[] = {
    nil, nil, nil, nil, nil, nil, nil
};

static NSString *value_dialogTimeFormat = nil;

static NSString *value_date_separator = @".";
static bool value_monthFirst = false;

static bool isArabic = false;
static bool isKorean = false;

static bool TGDateUtilsInitialized = false;
static void initializeTGDateUtils()
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    [dateFormatter setDateStyle:NSDateFormatterNoStyle];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    NSTimeZone *timeZone = [NSTimeZone localTimeZone];
    [dateFormatter setTimeZone:timeZone];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    NSRange amRange = [dateString rangeOfString:[dateFormatter AMSymbol]];
    NSRange pmRange = [dateString rangeOfString:[dateFormatter PMSymbol]];
    value_dateHas12hFormat = !(amRange.location == NSNotFound && pmRange.location == NSNotFound);
    
    dateString = [NSDateFormatter dateFormatFromTemplate:@"MdY" options:0 locale:[NSLocale currentLocale]];
    if ([dateString rangeOfString:@"."].location != NSNotFound)
    {
        value_date_separator = @".";
    }
    else if ([dateString rangeOfString:@"/"].location != NSNotFound)
    {
        value_date_separator = @"/";
    }
    else if ([dateString rangeOfString:@"-"].location != NSNotFound)
    {
        value_date_separator = @"-";
    }
    
    if ([dateString rangeOfString:[NSString stringWithFormat:@"M%@d", value_date_separator]].location != NSNotFound)
    {
        value_monthFirst = true;
    }
    
    NSString *identifier = [[NSLocale currentLocale] localeIdentifier];
    if ([identifier isEqualToString:@"ar"] || [identifier hasPrefix:@"ar_"])
    {
        isArabic = true;
        value_date_separator = @"\u060d";
    }
    else if ([identifier isEqualToString:@"ko"] || [identifier hasPrefix:@"ko-"])
    {
        isKorean = true;
    }
    
    value_monthNamesGenShort[0] = TGLocalized(@"Month.ShortJanuary");
    value_monthNamesGenShort[1] = TGLocalized(@"Month.ShortFebruary");
    value_monthNamesGenShort[2] = TGLocalized(@"Month.ShortMarch");
    value_monthNamesGenShort[3] = TGLocalized(@"Month.ShortApril");
    value_monthNamesGenShort[4] = TGLocalized(@"Month.ShortMay");
    value_monthNamesGenShort[5] = TGLocalized(@"Month.ShortJune");
    value_monthNamesGenShort[6] = TGLocalized(@"Month.ShortJuly");
    value_monthNamesGenShort[7] = TGLocalized(@"Month.ShortAugust");
    value_monthNamesGenShort[8] = TGLocalized(@"Month.ShortSeptember");
    value_monthNamesGenShort[9] = TGLocalized(@"Month.ShortOctober");
    value_monthNamesGenShort[10] = TGLocalized(@"Month.ShortNovember");
    value_monthNamesGenShort[11] = TGLocalized(@"Month.ShortDecember");
    
    value_monthNamesGenFull[0] = TGLocalized(@"Month.GenJanuary");
    value_monthNamesGenFull[1] = TGLocalized(@"Month.GenFebruary");
    value_monthNamesGenFull[2] = TGLocalized(@"Month.GenMarch");
    value_monthNamesGenFull[3] = TGLocalized(@"Month.GenApril");
    value_monthNamesGenFull[4] = TGLocalized(@"Month.GenMay");
    value_monthNamesGenFull[5] = TGLocalized(@"Month.GenJune");
    value_monthNamesGenFull[6] = TGLocalized(@"Month.GenJuly");
    value_monthNamesGenFull[7] = TGLocalized(@"Month.GenAugust");
    value_monthNamesGenFull[8] = TGLocalized(@"Month.GenSeptember");
    value_monthNamesGenFull[9] = TGLocalized(@"Month.GenOctober");
    value_monthNamesGenFull[10] = TGLocalized(@"Month.GenNovember");
    value_monthNamesGenFull[11] = TGLocalized(@"Month.GenDecember");
    
    value_weekdayNamesShort[0] = TGLocalized(@"Weekday.ShortMonday");
    value_weekdayNamesShort[1] = TGLocalized(@"Weekday.ShortTuesday");
    value_weekdayNamesShort[2] = TGLocalized(@"Weekday.ShortWednesday");
    value_weekdayNamesShort[3] = TGLocalized(@"Weekday.ShortThursday");
    value_weekdayNamesShort[4] = TGLocalized(@"Weekday.ShortFriday");
    value_weekdayNamesShort[5] = TGLocalized(@"Weekday.ShortSaturday");
    value_weekdayNamesShort[6] = TGLocalized(@"Weekday.ShortSunday");
    
    value_weekdayNamesFull[0] = TGLocalized(@"Weekday.Monday");
    value_weekdayNamesFull[1] = TGLocalized(@"Weekday.Tuesday");
    value_weekdayNamesFull[2] = TGLocalized(@"Weekday.Wednesday");
    value_weekdayNamesFull[3] = TGLocalized(@"Weekday.Thursday");
    value_weekdayNamesFull[4] = TGLocalized(@"Weekday.Friday");
    value_weekdayNamesFull[5] = TGLocalized(@"Weekday.Saturday");
    value_weekdayNamesFull[6] = TGLocalized(@"Weekday.Sunday");
    
    value_dialogTimeFormat = [[TGLocalized(@"Date.DialogDateFormat") stringByReplacingOccurrencesOfString:@"{month}" withString:@"%1$@"] stringByReplacingOccurrencesOfString:@"{day}" withString:@"%2$@"];
    
    TGDateUtilsInitialized = true;
}

static inline bool dateHas12hFormat()
{
    if (!TGDateUtilsInitialized)
        initializeTGDateUtils();
    
    return value_dateHas12hFormat;
}

bool TGUse12hDateFormat()
{
    if (!TGDateUtilsInitialized)
        initializeTGDateUtils();
    
    return value_dateHas12hFormat;
}

static inline NSString *weekdayNameShort(int number)
{
    if (!TGDateUtilsInitialized)
        initializeTGDateUtils();
    
    if (number < 0)
        number = 0;
    if (number > 6)
        number = 6;
    
    if (number == 0)
        number = 6;
    else
        number--;
    
    return value_weekdayNamesShort[number];
}

static inline NSString *weekdayNameFull(int number)
{
    if (!TGDateUtilsInitialized)
        initializeTGDateUtils();
    
    if (number < 0)
        number = 0;
    if (number > 6)
        number = 6;
    
    if (number == 0)
        number = 6;
    else
        number--;
    
    return value_weekdayNamesFull[number];
}

static inline NSString *monthNameGenFull(int number)
{
    if (!TGDateUtilsInitialized)
        initializeTGDateUtils();
    
    if (number < 0)
        number = 0;
    if (number > 11)
        number = 11;
    
    return value_monthNamesGenFull[number];
}

static inline NSString *dialogTimeFormat()
{
    if (!TGDateUtilsInitialized)
        initializeTGDateUtils();
    
    return value_dialogTimeFormat;
}

@implementation TGDateUtils

+ (void)reset
{
    TGDateUtilsInitialized = false;
}

+ (NSString *)stringForShortTime:(int)time
{
    time_t t = time;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    return [self stringForShortTimeWithHours:timeinfo.tm_hour minutes:timeinfo.tm_min];
}

+ (NSString *)stringForShortTimeWithHours:(int)hours minutes:(int)minutes
{
    if (!TGDateUtilsInitialized)
        initializeTGDateUtils();
    
    if (isArabic)
    {
        if (dateHas12hFormat())
        {
            if (hours < 12)
                return [TGStringUtils stringWithLocalizedNumberCharacters:[[NSString alloc] initWithFormat:@"%d:%02d ص", hours == 0 ? 12 : hours, minutes]];
            else
                return [TGStringUtils stringWithLocalizedNumberCharacters:[[NSString alloc] initWithFormat:@"%d:%02d م", (hours - 12 == 0) ? 12 : (hours - 12), minutes]];
        }
        else
            return [TGStringUtils stringWithLocalizedNumberCharacters:[[NSString alloc] initWithFormat:@"%02d:%02d", hours, minutes]];
    }
    else if (isKorean)
    {
        return [[NSString alloc] initWithFormat:@"%02d:%02d", hours, minutes];
    }
    else
    {
        if (dateHas12hFormat())
        {
            if (hours < 12)
                return [[NSString alloc] initWithFormat:@"%d:%02d AM", hours == 0 ? 12 : hours, minutes];
            else
                return [[NSString alloc] initWithFormat:@"%d:%02d PM", (hours - 12 == 0) ? 12 : (hours - 12), minutes];
        }
        else
            return [[NSString alloc] initWithFormat:@"%02d:%02d", hours, minutes];
    }
}

+ (NSString *)stringForShortTime:(int)time daytimeVariant:(int *)__unused daytimeVariant
{
    return [self stringForShortTime:time];
}

+ (NSString *)stringForDialogTime:(int)time
{
    time_t t = time;
    struct tm timeinfo;
    gmtime_r(&t, &timeinfo);
    
    return [[NSString alloc] initWithFormat:dialogTimeFormat(), monthNameGenFull(timeinfo.tm_mon), [TGStringUtils stringWithLocalizedNumber:timeinfo.tm_mday]];
}

+ (NSString *)stringForDayOfWeek:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    return weekdayNameFull(timeinfo.tm_wday);
}

+ (NSString *)stringForMonthOfYear:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    NSString *format = TGLocalized(([[NSString alloc] initWithFormat:@"Time.MonthOfYear_m%d", (int)timeinfo.tm_mon + 1]));
    
    return [[NSString alloc] initWithFormat:format, [[NSString alloc] initWithFormat:@"%d", 2000 + timeinfo.tm_year - 100]];
}

+ (NSString *)stringForFullDateWithDay:(int)day month:(int)month year:(int)year
{
    if (isArabic)
    {
        return [TGStringUtils stringWithLocalizedNumberCharacters:[[NSString alloc] initWithFormat:@"%d%@%d%@%02d", day, value_date_separator, month, value_date_separator, year - 100]];
    }
    else if (isKorean)
    {
        return [TGStringUtils stringWithLocalizedNumberCharacters:[[NSString alloc] initWithFormat:@"%04d년 %d월 %d일", year - 100 + 2000, month, day]];
    }
    else
    {
        if (value_monthFirst)
        {
            return [[NSString alloc] initWithFormat:@"%d%@%d%@%02d", month, value_date_separator, day, value_date_separator, year - 100];
        }
        else
        {
            return [[NSString alloc] initWithFormat:@"%d%@%02d%@%02d", day, value_date_separator, month, value_date_separator, year - 100];
        }
    }
}

+ (NSString *)stringForPreciseDate:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    NSString *format = TGLocalized(([[NSString alloc] initWithFormat:@"Time.PreciseDate_m%d", (int)timeinfo.tm_mon + 1]));
    return [[NSString alloc] initWithFormat:format, [[NSString alloc] initWithFormat:@"%d", timeinfo.tm_mday], [[NSString alloc] initWithFormat:@"%d", (int)(2000 + timeinfo.tm_year - 100)], [self stringForShortTimeWithHours:timeinfo.tm_hour minutes:timeinfo.tm_min]];
}

+ (NSString *)stringForMessageListDate:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    if (timeinfo.tm_year != timeinfo_now.tm_year)
    {
        return [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year];
    }
    else
    {
        int dayDiff = timeinfo.tm_yday - timeinfo_now.tm_yday;
        
        if(dayDiff == 0)
            return [self stringForShortTime:date];
        else if(dayDiff == -1)
            return weekdayNameFull(timeinfo.tm_wday);
        else if(dayDiff == -2)
            return weekdayNameFull(timeinfo.tm_wday);
        else if(dayDiff > -7 && dayDiff <= -2)
            return weekdayNameFull(timeinfo.tm_wday);
        else
            return [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year];
    }
    
    return nil;
}

+ (NSString *)stringForApproximateDate:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    if (timeinfo.tm_year != timeinfo_now.tm_year)
        return [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year];
    else
    {
        int dayDiff = timeinfo.tm_yday - timeinfo_now.tm_yday;
        
        if(dayDiff == 0 || dayDiff == -1)
            return [self stringForTodayOrYesterday:dayDiff == 0 hours:timeinfo.tm_hour minutes:timeinfo.tm_min];
        else if (false && dayDiff > -7 && dayDiff <= -2)
            return weekdayNameShort(timeinfo.tm_wday);
        else
            return [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year];
    }
    
    return nil;
}

+ (NSString *)stringForFullDate:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    return [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year];
}

+ (NSString *)stringForTodayOrYesterday:(bool)today hours:(int)hours minutes:(int)minutes
{
    NSString *timeString = [self stringForShortTimeWithHours:hours minutes:minutes];
    
    return [[NSString alloc] initWithFormat:today ? TGLocalized(@"Time.TodayAt") : TGLocalized(@"Time.YesterdayAt"), timeString];
}

+ (NSString *)stringForLastSeenTodayOrYesterday:(bool)today hours:(int)hours minutes:(int)minutes
{
    NSString *timeString = [self stringForShortTimeWithHours:hours minutes:minutes];
    
    return [[NSString alloc] initWithFormat:today ? TGLocalized(@"Watch.LastSeen.TodayAt") : TGLocalized(@"Watch.LastSeen.YesterdayAt"), timeString];
}

+ (NSString *)stringForLastSeen:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    if (timeinfo.tm_year != timeinfo_now.tm_year)
        return [[NSString alloc] initWithFormat:TGLocalized(@"Watch.LastSeen.AtDate"), [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year]];
    else
    {
        int dayDiff = timeinfo.tm_yday - timeinfo_now.tm_yday;
        
        if(dayDiff == 0 || dayDiff == -1)
            return [self stringForLastSeenTodayOrYesterday:dayDiff == 0 hours:timeinfo.tm_hour minutes:timeinfo.tm_min];
        else if (false && dayDiff > -7 && dayDiff <= -2)
            return [[NSString alloc] initWithFormat:TGLocalized(@"Watch.LastSeen.AtWeekday"), weekdayNameShort(timeinfo.tm_wday)];
        else
            return [[NSString alloc] initWithFormat:TGLocalized(@"Watch.LastSeen.AtDate"), [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year]];
    }
    
    return nil;
}

+ (NSString *)stringForRelativeLastSeen:(int)date
{
    if (date == -1)
        return TGLocalized(@"Presence.invisible");
    else if (date == TGDateRelativeSpanLately)
        return TGLocalized(@"Watch.LastSeen.Lately");
    else if (date == TGDateRelativeSpanWithinAWeek)
        return TGLocalized(@"Watch.LastSeen.WithinAWeek");
    else if (date == TGDateRelativeSpanWithinAMonth)
        return TGLocalized(@"Watch.LastSeen.WithinAMonth");
    else if (date == TGDateRelativeSpanALongTimeAgo)
        return TGLocalized(@"Watch.LastSeen.ALongTimeAgo");
    else if (date <= 0)
        return TGLocalized(@"Presence.offline");
    
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    if (timeinfo.tm_year != timeinfo_now.tm_year)
        return [[NSString alloc] initWithFormat:TGLocalized(@"Watch.LastSeen.AtDate"), [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year]];
    else
    {
        int dayDiff = timeinfo.tm_yday - timeinfo_now.tm_yday;
        
        int minutesDiff = (int)((t_now - date) / 60);
        int hoursDiff = (int)((t_now - date) / (60 * 60));
        
        if (dayDiff == 0 && hoursDiff <= 23)
        {
            if (minutesDiff < 1)
                return TGLocalized(@"Watch.LastSeen.JustNow");
            else if (minutesDiff < 60)
            {
                if (minutesDiff == 1)
                    return TGLocalized(@"Watch.LastSeen.MinutesAgo_1");
                else if (minutesDiff == 2)
                    return TGLocalized(@"Watch.LastSeen.MinutesAgo_2");
                else if (minutesDiff >= 3 && minutesDiff <= 10)
                    return [[NSString alloc] initWithFormat:TGLocalized(@"Watch.LastSeen.MinutesAgo_3_10"), [TGStringUtils stringWithLocalizedNumber:minutesDiff]];
                else
                    return [[NSString alloc] initWithFormat:TGLocalized(@"Watch.LastSeen.MinutesAgo_any"), [TGStringUtils stringWithLocalizedNumber:minutesDiff]];
            }
            else
            {
                if (hoursDiff == 1)
                    return TGLocalized(@"Watch.LastSeen.HoursAgo_1");
                else if (hoursDiff == 2)
                    return TGLocalized(@"Watch.LastSeen.HoursAgo_2");
                else if (hoursDiff >= 3 && hoursDiff <= 10)
                    return [[NSString alloc] initWithFormat:TGLocalized(@"Watch.LastSeen.HoursAgo_3_10"), [TGStringUtils stringWithLocalizedNumber:hoursDiff]];
                else
                    return [[NSString alloc] initWithFormat:TGLocalized(@"Watch.LastSeen.HoursAgo_any"), [TGStringUtils stringWithLocalizedNumber:hoursDiff]];
            }
        }
        else if (dayDiff == 0 || dayDiff == -1)
            return [self stringForLastSeenTodayOrYesterday:dayDiff == 0 hours:timeinfo.tm_hour minutes:timeinfo.tm_min];
        else
            return [[NSString alloc] initWithFormat:TGLocalized(@"Watch.LastSeen.AtDate"), [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year]];
    }
    
    return nil;
}

+ (TGChatTimestamp *)timestampForDateIfNeeded:(int)date previousDate:(NSNumber *)previousDate
{
    if (previousDate == nil)
        return [self timestampForDate:date];
    
    TGChatTimestamp *timestamp = nil;
    
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_prev = previousDate.integerValue;
    struct tm timeinfo_prev;
    localtime_r(&t_prev, &timeinfo_prev);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    bool timestampNeeded = false;
    
    if (timeinfo.tm_yday != timeinfo_prev.tm_yday)
    {
        timestampNeeded = true;
    }
    else
    {
        if (timeinfo.tm_year != timeinfo_prev.tm_year)
        {
            timestampNeeded = true;
        }
        else
        {
            if (timeinfo.tm_year == timeinfo_now.tm_year)
            {
                if (timeinfo_now.tm_yday - timeinfo.tm_yday < 7)
                {
                    if (abs(t - t_prev) > 3600)
                        timestampNeeded = true;
                }
            }
        }
    }
    
    if (timestampNeeded)
        timestamp = [self timestampForDate:date];
    
    return timestamp;
}

+ (TGChatTimestamp *)timestampForDate:(int)date
{
    time_t t = date;
    struct tm timeinfo;
    localtime_r(&t, &timeinfo);
    
    time_t t_now;
    time(&t_now);
    struct tm timeinfo_now;
    localtime_r(&t_now, &timeinfo_now);
    
    NSString *string = nil;
    if (timeinfo.tm_year != timeinfo_now.tm_year)
    {
        string = [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year];
    }
    else
    {
        int dayDiff = timeinfo.tm_yday - timeinfo_now.tm_yday;
        
        if (dayDiff == 0 || dayDiff == -1)
        {
            string = [NSString stringWithFormat:dayDiff == 0 ? TGLocalized(@"Watch.Time.ShortTodayAt") : TGLocalized(@"Watch.Time.ShortYesterdayAt"), [self stringForShortTimeWithHours:timeinfo.tm_hour minutes:timeinfo.tm_min]];
        }
        else if (dayDiff > -7)
        {
            string = [NSString stringWithFormat:TGLocalized(@"Watch.Time.ShortWeekdayAt"), [self stringForDayOfWeek:timeinfo.tm_wday], [self stringForShortTimeWithHours:timeinfo.tm_hour minutes:timeinfo.tm_min]];
        }
        else
        {
            string = [NSString stringWithFormat:TGLocalized(@"Watch.Time.ShortFullAt"), [self stringForFullDateWithDay:timeinfo.tm_mday month:timeinfo.tm_mon + 1 year:timeinfo.tm_year], [self stringForShortTimeWithHours:timeinfo.tm_hour minutes:timeinfo.tm_min]];
        }
    }
    
    return [[TGChatTimestamp alloc] initWithDate:date string:string];
}

@end
