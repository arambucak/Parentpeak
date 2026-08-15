const menuButton = document.querySelector('.menu-toggle');
const navigation = document.querySelector('#main-nav');

menuButton?.addEventListener('click', () => {
  const isOpen = menuButton.getAttribute('aria-expanded') === 'true';
  menuButton.setAttribute('aria-expanded', String(!isOpen));
  navigation.classList.toggle('is-open', !isOpen);
});

navigation?.addEventListener('click', (event) => {
  if (event.target.closest('a')) {
    menuButton?.setAttribute('aria-expanded', 'false');
    navigation.classList.remove('is-open');
  }
});

const weeklyForm = document.querySelector('#weekly-form');
const weeklyResult = document.querySelector('#weekly-result');
const resetWeekButton = document.querySelector('#reset-week');

weeklyForm?.addEventListener('submit', (event) => {
  event.preventDefault();
  const data = new FormData(weeklyForm);
  const values = ['appointment', 'priority', 'connection']
    .map((key) => String(data.get(key) || '').trim())
    .filter(Boolean);

  const list = weeklyResult.querySelector('ol');
  list.replaceChildren(...values.map((value) => {
    const item = document.createElement('li');
    item.textContent = value;
    return item;
  }));

  weeklyForm.hidden = true;
  weeklyResult.hidden = false;
  weeklyResult.focus({ preventScroll: true });
});

resetWeekButton?.addEventListener('click', () => {
  weeklyForm.reset();
  weeklyResult.hidden = true;
  weeklyForm.hidden = false;
  weeklyForm.querySelector('input')?.focus();
});
