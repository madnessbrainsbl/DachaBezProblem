import 'package:flutter/material.dart';
import 'calendar_styles.dart';
import 'home_styles.dart';
import '../pages/day_detail_page.dart';

class CalendarComponent extends StatelessWidget {
  const CalendarComponent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Получаем текущую дату
    final DateTime now = DateTime.now();

    // Вычисляем начало недели (понедельник)
    // Если сегодня понедельник (1), то вычитаем 0 дней
    // Если сегодня вторник (2), то вычитаем 1 день и т.д.
    final int weekday = now.weekday;
    final DateTime monday = now.subtract(Duration(days: weekday - 1));

    // Создаем список дат на всю неделю
    final List<DateTime> weekDates =
        List.generate(7, (index) => monday.add(Duration(days: index)));

    return Container(
      height: 120,
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Days of week row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SizedBox(
                    width: 30,
                    child: Center(
                        child:
                            Text('Пн', style: CalendarStyles.dayLabelStyle))),
                SizedBox(
                    width: 30,
                    child: Center(
                        child:
                            Text('Вт', style: CalendarStyles.dayLabelStyle))),
                SizedBox(
                    width: 30,
                    child: Center(
                        child:
                            Text('Ср', style: CalendarStyles.dayLabelStyle))),
                SizedBox(
                    width: 30,
                    child: Center(
                        child:
                            Text('Чт', style: CalendarStyles.dayLabelStyle))),
                SizedBox(
                    width: 30,
                    child: Center(
                        child:
                            Text('Пт', style: CalendarStyles.dayLabelStyle))),
                SizedBox(
                    width: 30,
                    child: Center(
                        child:
                            Text('Сб', style: CalendarStyles.dayLabelStyle))),
                SizedBox(
                    width: 30,
                    child: Center(
                        child:
                            Text('Вс', style: CalendarStyles.dayLabelStyle))),
              ],
            ),
          ),
          const SizedBox(height: 15),
          // Dates row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final date = weekDates[index];
                final isToday = date.day == now.day &&
                    date.month == now.month &&
                    date.year == now.year;

                return GestureDetector(
                  onTap: () async {
                    try {
                      // Переход к странице деталей дня
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DayDetailPage(
                            selectedDate: DateTime.utc(date.year, date.month, date.day),
                          ),
                        ),
                      );
                    } catch (e) {
                      print('Ошибка при переходе к DayDetailPage: $e');
                      // Можно показать SnackBar с ошибкой
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ошибка при открытии дня'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: SizedBox(
                    width: 30,
                    child: isToday
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: HomeStyles.primaryGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(
                                '${date.day}',
                                style: CalendarStyles.selectedDateStyle,
                              ),
                            ],
                          )
                        : Center(
                            child: Text(
                              '${date.day}',
                              style: CalendarStyles.dateStyle,
                            ),
                          ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 15),
          // Bottom line
          Center(
            child: Container(
              width: 60,
              height: 2,
              color: const Color(0xFFDDDDDD),
            ),
          ),
        ],
      ),
    );
  }
}
