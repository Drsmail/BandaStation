import { afterEach, describe, expect, it } from 'bun:test';
import { act, cleanup, render, screen } from '@testing-library/react';
import { gameDataAtom, store } from '../events/store';
import { CharacterPortraitModeration } from './CharacterPortraitModeration';
import { CharacterPortraits } from './CharacterPortraits';

afterEach(cleanup);

const setPortrait = (status: string, busy = false) => {
  store.set(gameDataAtom, {
    images: [
      {
        key: 'portrait-id',
        filename: 'portrait.png',
        uploader_ckey: 'alice',
        status,
        reviewer_ckey: null,
      },
    ],
    selected_image_key: 'portrait-id',
    selected_image_data: null,
    list_state: 'loaded',
    status_message: '',
    status_is_error: false,
    service_configured: true,
    processor_available: true,
    upload_in_progress: false,
    active_portrait_id: null,
    character_slot: 2,
    busy,
  });
};

describe('Character portraits', () => {
  it('allows character selection only after approval', () => {
    setPortrait('pending');
    act(() => render(<CharacterPortraits />));
    expect(
      screen
        .getByText('Выбрать')
        .closest('.Button')
        ?.classList.contains('Button--disabled'),
    ).toBe(true);
    cleanup();
    setPortrait('approved');
    act(() => render(<CharacterPortraits />));
    expect(
      screen
        .getByText('Выбрать')
        .closest('.Button')
        ?.classList.contains('Button--disabled'),
    ).not.toBe(true);
  });

  it('only permits moderation of pending portraits', () => {
    setPortrait('approved');
    act(() => render(<CharacterPortraitModeration />));
    expect(
      screen
        .getByText('Одобрить')
        .closest('.Button')
        ?.classList.contains('Button--disabled'),
    ).toBe(true);
    expect(
      screen
        .getByText('Отклонить')
        .closest('.Button')
        ?.classList.contains('Button--disabled'),
    ).toBe(true);
    cleanup();
    setPortrait('pending');
    act(() => render(<CharacterPortraitModeration />));
    expect(
      screen
        .getByText('Одобрить')
        .closest('.Button')
        ?.classList.contains('Button--disabled'),
    ).not.toBe(true);
    expect(
      screen
        .getByText('Отклонить')
        .closest('.Button')
        ?.classList.contains('Button--disabled'),
    ).not.toBe(true);
  });

  it('disables moderation while a decision is being saved', () => {
    setPortrait('pending', true);
    act(() => render(<CharacterPortraitModeration />));
    expect(
      screen
        .getByText('Одобрить')
        .closest('.Button')
        ?.classList.contains('Button--disabled'),
    ).toBe(true);
    expect(
      screen
        .getByText('Отклонить')
        .closest('.Button')
        ?.classList.contains('Button--disabled'),
    ).toBe(true);
  });
});
