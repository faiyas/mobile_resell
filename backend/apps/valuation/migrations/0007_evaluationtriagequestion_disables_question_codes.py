from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('valuation', '0006_evaluationtriagequestion'),
    ]

    operations = [
        migrations.AddField(
            model_name='evaluationtriagequestion',
            name='disables_question_codes',
            field=models.JSONField(blank=True, default=list, help_text="List of question codes to automatically turn OFF/skip if user answers 'No'"),
        ),
    ]
