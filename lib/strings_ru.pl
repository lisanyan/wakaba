use utf8;

use constant S_HOME => 'Домой'; # Forwards to home page
use constant S_ADMIN => 'Управление'; # Forwards to Management Panel
use constant S_RETURN => 'Назад'; # Returns to image board
use constant S_POSTING => 'Режим отправки: ответ'; # Prints message in red bar atop the reply screen
use constant S_BOARD => 'Доска';

use constant S_NAME => 'Имя'; # Describes name field
use constant S_EMAIL => 'Ссылка'; # Describes e-mail field
use constant S_SUBJECT => 'Тема'; # Describes subject field
use constant S_SUBMIT => 'Отправить'; # Describes submit button
use constant S_COMMENT => 'Текст'; # Describes comment field
use constant S_UPLOADFILE => 'Файл'; # Describes file field
use constant S_NOFILE => 'Файла нет'; # Describes file/no file checkbox
use constant S_CAPTCHA => 'Подтверждение'; # Describes captcha field
use constant S_PARENT => 'Предок'; # Describes parent field on admin post page
use constant S_DELPASS => 'Пароль'; # Describes password field
use constant S_DELEXPL => '(для удаления поста и файлов)'; # Prints explanation for password box (to the right)
use constant S_SPAMTRAP => 'Оставь эти поля пустыми: ';
use constant S_SAGE => 'Sage';
use constant S_SAGEDESC => 'Не поднимать тред';

use constant S_THUMB => 'Изображение уменьшено, кликни для увеличения.'; # Prints instructions for viewing real source
use constant S_HIDDEN => 'Изображение скрыто, кликни имя файла для отображения.'; # Prints instructions for viewing hidden image reply
use constant S_NOTHUMB => 'Нет<br />изображения'; # Printed when there's no thumbnail
use constant S_PICNAME => ''; # Prints text before upload name/link
use constant S_REPLY => 'Ответить'; # Prints text for reply link
use constant S_VIEW => 'Посмотреть'; # Prints text for reply link
use constant S_OLD => 'Отмечено для удаления (устарел).'; # Prints text to be displayed before post is marked for deletion, see: retention
use constant S_ABBR => 'Пропущено постов: %d. Кликни Ответить для просмотра.'; # Prints text to be shown when replies are hidden
use constant S_ABBRIMG => 'Пропущено постов: %d, изображений: %d. Кликни Ответить для просмотра'; # Prints text to be shown when replies and images are hidden
use constant S_ABBRTEXT => 'Комментарий слишком длинный. Кликни <a href="%s">сюда</a> чтобы увидеть его весь.';

use constant S_REPDEL => 'Удалить пост '; # Prints text next to S_DELPICONLY (left)
use constant S_DELPICONLY => 'Только файл'; # Prints text next to checkbox for file deletion (right)
use constant S_DELKEY => 'Пароль '; # Prints text next to password field for deletion (left)
use constant S_DELETE => 'Удалить'; # Defines deletion button's name

use constant S_PREV => 'Предыдущие'; # Defines previous button
use constant S_FIRSTPG => 'Предыдущие'; # Defines previous button
use constant S_NEXT => 'Следующие'; # Defines next button
use constant S_LASTPG => 'Следующие'; # Defines next button

use constant S_WEEKDAYS => 'Вск Пон Втр Срд Чтв Птн Сбт'; # Defines abbreviated weekday names.
use constant S_MONTHS => 'Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь';

use constant S_MANARET => 'Назад'; # Returns to HTML file instead of PHP--thus no log/SQLDB update occurs
use constant S_MANAMODE => 'Режим управления'; # Prints heading on top of Manager page

use constant S_MANALOGIN => 'Вход администратора'; # Defines Management Panel radio button--allows the user to view the management panel (overview of all posts)
use constant S_ADMINPASS => 'Пароль администратора:'; # Prints login prompt

use constant S_MANAPANEL => 'Панель управления'; # Defines Management Panel radio button--allows the user to view the management panel (overview of all posts)
use constant S_MANABANS => 'Баны/Белый список'; # Defines Bans Panel button
use constant S_MANAORPH => 'Потерянные файлы';
use constant S_MANASHOW => 'Показать';
use constant S_MANAREBUILD => 'Пересоздать кеши';							#
use constant S_MANALOGOUT => 'Выйти';									#
use constant S_MANASAVE => 'Запомнить меня на этой машине'; # Defines Label for the login cookie checbox
use constant S_MANASUB => 'Отправить!'; # Defines name for submit button in Manager Mode

use constant S_NOTAGS => 'Теги HTML разрешены. Никакого форматирования не будет, ставь переводы строк и абзацы самостоятельно.'; # Prints message on Management Board
use constant S_NOTAGS2 => 'No format.'; # Prints message on Management Board

use constant S_POSTASADMIN => 'Пост как админ';
use constant S_REPORTSNUM => 'No. Поста';
use constant S_REPORTSBOARD => 'Доска';
use constant S_REPORTSDATE => 'Дата &amp; Время';
use constant S_REPORTSCOMMENT => 'Текст';
use constant S_REPORTSIP => 'IP';
use constant S_REPORTSDISMISS => 'Отклонить';

use constant S_MPDELETEIP => 'Удалить все';
use constant S_MPDELETE => 'Удалить'; # Defines for deletion button in Management Panel
use constant S_MPARCHIVE => 'Архив';
use constant S_MPRESET => 'Сброс'; # Defines name for field reset button in Management Panel
use constant S_MPONLYPIC => 'Только файл'; # Sets whether or not to delete only file, or entire post/thread
use constant S_MPDELETEALL => 'Уд.&nbsp;все';
use constant S_MPLOCK => 'Закрыть';
use constant S_MPAUTOSAGE => 'Автосажа';
use constant S_MPBAN => 'Бан'; # Sets whether or not to delete only file, or entire post/thread
use constant S_IMGSPACEUSAGE => '[ Используется места: %s ]'; # Prints space used KB by the board under Management Panel

use constant S_DELALLMSG => 'Затронуто';
use constant S_DELALLCOUNT => 'Постов: %d (Тредов: %d)';
use constant S_ALLOWED => 'Разрешенные типы файлов (Лимит: %s)';

use constant S_ABBR1 => '1 Пост '; # Prints text to be shown when replies are hidden
use constant S_ABBR2 => '%d Постов ';
use constant S_ABBRIMG1 => 'и 1 Файл '; # Prints text to be shown when replies and files are hidden
use constant S_ABBRIMG2 => 'и %d Файлов ';
use constant S_ABBR_END => 'скрыто.';

use constant S_ABBRTEXT1 => 'One more line';
use constant S_ABBRTEXT2 => '%d more lines';

use constant S_BANTABLE => '<th>Тип</th><th>Дата</th><th>Истекает</th>'
                            .'<th colspan="2">Значение</th><th>Текст</th><th>Действие</th>'; # Explains names for Ban Panel
use constant S_BANIPLABEL => 'IP';
use constant S_BANMASKLABEL => 'Маска';
use constant S_BANCOMMENTLABEL => 'Текст';
use constant S_BANWORDLABEL => 'Слово';
use constant S_BANEXPIRESLABEL => 'Истекает';
use constant S_BANIP => 'Бан по IP';
use constant S_BANWORD => 'Бан по слову';
use constant S_BANWHITELIST => 'Белый список';
use constant S_BANREMOVE => 'Удалить';
use constant S_BANCOMMENT => 'Текст';
use constant S_BANTRUST => 'Без капчи';
use constant S_BANTRUSTTRIP => 'Трипкод';
use constant S_BANSECONDS => '(секунды)';
use constant S_BANEXPIRESNEVER => 'Никогда';

use constant S_SEARCHTITLE => 'Поиск';
use constant S_SEARCH => 'Поиск';
use constant S_SEARCHCOMMENT => 'В постах';
use constant S_SEARCHSUBJECT => 'В теме';
use constant S_SEARCHFILES => 'В файлах';
use constant S_SEARCHOP => 'Только в ОП-постах';
use constant S_SEARCHSUBMIT => 'Искать';
use constant S_SEARCHFOUND => 'Найдено:';
use constant S_OPTIONS => 'Опции';
use constant S_MINLENGTH => '(мин. 3 символа)';

use constant S_STATS => 'Stats';
use constant S_STATSTITLE => 'Post Statistics';
use constant S_DATE => 'Date';

use constant S_REPORTHEAD => 'Жалобы';
use constant S_REPORTEXPL => 'Вы жалуетесь следующие посты:';
use constant S_REPORTREASON => 'Пожалуйста введите причину:';
use constant S_REPORT => 'Жалоба'; # Defines report button's name
use constant S_REPORTSUCCESS => 'Спасибо за репорт! Модераторы были оповещены и рассмотрят вашу жалобу.';

# javascript message strings (do not use HTML entities; mask single quotes with \\\')
use constant S_JS_REMOVEFILE => 'Удалить файл';
use constant S_JS_SHOWTHREAD => 'Показать тред (+)';
use constant S_JS_HIDETHREAD => 'Скрыть тред (\u2212)';
use constant S_HIDETHREAD => 'Скрыть тред (&minus;)';
# javascript strings END

use constant S_BADIP => 'Плохое значение IP';

use constant S_TOOBIG => 'Изображение слишком большое! Залей что-нибудь поменьше!';
use constant S_TOOBIGORNONE => 'Либо изображение слишком большое, либо его вообще не было. Ага.';
use constant S_REPORTERR => 'Не могу найти ответ.'; # Returns error when a reply (res) cannot be found
use constant S_UPFAIL => 'Сбой при загрузке.'; # Returns error for failed upload (reason: unknown?)
use constant S_NOREC => 'Не могу найти запись.'; # Returns error when record cannot be found
use constant S_NOCAPTCHA => 'Капча протухла.'; # Returns error when there's no captcha in the database for this IP/key
use constant S_BADCAPTCHA => 'Код подтверждения неверен.'; # Returns error when the captcha is wrong
use constant S_BADFORMAT => 'Формат файла не поддерживается.'; # Returns error when the file is not in a supported format.
use constant S_STRREF => 'Строка отклонена.'; # Returns error when a string is refused
use constant S_UNJUST => 'Хреновый POST.'; # Returns error on an unjust POST - prevents floodbots or ways not using POST method?
use constant S_NOPIC => 'Файл не выбран. Забыл клацнуть "Ответить"?'; # Returns error for no file selected and override unchecked
use constant S_NOTEXT => 'Текст не введён.'; # Returns error for no text entered in to subject/comment
use constant S_TOOLONG => 'Слишком много символов в текстовом поле.'; # Returns error for too many characters in a given field
use constant S_NOTALLOWED => 'Отправка не разрешена.'; # Returns error for non-allowed post types
use constant S_UNUSUAL => 'Аномальный ответ.'; # Returns error for abnormal reply? (this is a mystery!)
use constant S_BADHOST => 'Хост забанен.'; # Returns error for banned host ($badip string)
use constant S_BADHOSTPROXY => 'Прокси забанено.'; # Returns error for banned proxy ($badip string)
use constant S_RENZOKU => 'Обнаружен флуд, пост отвергнут.'; # Returns error for $sec/post spam filter
use constant S_RENZOKU2 => 'Обнаружен флуд, файл отвергнут.'; # Returns error for $sec/upload spam filter
use constant S_RENZOKU3 => 'Обнаружен флуд.'; # Returns error for $sec/similar posts spam filter.
use constant S_RENZOKU4 => 'Период ожидания перед удалением еще не истек.'; # Returns error for deleting
use constant S_RENZOKU5 => 'Обнаружен флуд. Подождите (%d) минут.';
use constant S_PROXY => 'Обнаружен открытый прокси.'; # Returns error for proxy detection.
use constant S_DUPE => 'Файл уже залит <a href="%s">здесь</a>.'; # Returns error when an md5 checksum already exists.
use constant S_DUPENAME => 'Файл с тем же именем уже есть.'; # Returns error when an filename already exists.
use constant S_NOTHREADERR => 'Треда не существует.'; # Returns error when a non-existant thread is accessed
use constant S_BADDELPASS => 'Неверный пароль на удаление.'; # Returns error for wrong password (when user tries to delete file)
use constant S_BADDELIP => 'Неверный IP.';
use constant S_NOPOSTS => 'Вы не выбрали ни одного поста!';
use constant S_CANNOTREPORT => 'Вы не можете репортить на этой доске.';
use constant S_REPORTSFLOOD => 'Вы можете зарепортить не более %d постов.';
use constant S_WRONGPASS => 'Неверный пароль админа.'; # Returns error for wrong password (when trying to access Manager modes)
use constant S_VIRUS => 'Файл может быть инфицирован.'; # Returns error for malformed files suspected of being virus-infected.
use constant S_NOTWRITE => 'Не могу писать в каталог.'; # Returns error when the script cannot write to the directory, the chmod (777) is wrong
use constant S_SPAM => 'Спамеры идут лесом.'; # Returns error when detecting spam
use constant S_NOTEXISTPOST => 'Пост No.%d не существует.';

use constant S_LOCKED => 'Тред закрыт.';
use constant S_NOBOARDACC => 'У вас нет доступа к этой доске, доступные: %s<br /><a href="%s?task=logout">Выход</a>';
use constant S_PREWRAP => '<span class="prewrap">%s</span>';
use constant S_THREADLOCKED => '<strong>Тред %s</strong> закрыт. Вы не можете отвечать в этот тред.';
use constant S_FILEINFO => 'Информация';
use constant S_FILEDELETED => 'Файл удален';
use constant S_FILENAME => 'Имя файла:';
use constant S_ICONAUTOSAGE => 'Бамплимит';
use constant S_ICONLOCKED => 'Закрыт';
use constant S_BANNED => 'Пользователь был забанен за этот пост';

use constant S_DNSBL => 'Ваш IP находитсяв черном списке <em>%s</em>!'; # error string for tor node check
use constant S_AUTOBAN => 'Spambot [Auto Ban]'; # Ban reason for automatically created bans

use constant S_SQLCONF => 'Ошибка подключения SQL'; # Database connection failure
use constant S_SQLFAIL => 'Критическая ошибка SQL!'; # SQL Failure

use constant S_REDIR => 'Если перенаправление не сработало, выбери какое-нибудь из следующих зеркал:'; # Redir message for html in REDIR_DIR

1;
