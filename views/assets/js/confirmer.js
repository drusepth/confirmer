$(document).ready(function () {
	var results_table  = $('#results-table'),
	    ask_button     = $('#ask-button'),
	    question_field = $('#question');

	var ask_function = function () {
		ask_button.text('Asking...');
		$.get('/proof', {question: question_field.val()}, function (response) {
			results_table.find('tbody').html('');
			results_table.find('thead').show();

			if (response.length == 0) {
				results_table.find('thead').hide();
				var cancel_text = "I'm sorry, but HL3 has been cancelled. Please ask something else, like 'Is HL3 coming out?'";
				results_table.append($('<tr />').append($('<td />').text(cancel_text)));
			}

			for (i = 0; i < response.length; i++) {
				var row = $('<tr />').append($('<td />').text(response[i]));
				results_table.append(row);
			}
			results_table.show();
			ask_button.text('Ask');
		}, "json");
	}

	// Trigger bindings
	ask_button.click(function () { ask_function(); return false; });
	question_field.keyup(function (e) { if (e.keyCode == 13) { ask_function(); } });
});